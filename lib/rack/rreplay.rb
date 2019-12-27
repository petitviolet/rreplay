# frozen_string_literal: true

require 'securerandom'
require 'msgpack'
require 'json'
require 'time'

module Rack
  class Rreplay
    class << self
      # @param directory [String] rreplay dump file directory, and if nil, use logger as debug
      # @param logger [IO] if directory is nil, logger can be given
      def Middleware(directory:, logger: nil)
        if directory
          ::FileUtils.mkdir_p(directory)
          _logger = ::Logger::LogDevice.new(::File.join(directory, "rreplay.log"), shift_age: 10, shift_size: 1048576)
        else
          _logger = logger
        end
        class_definition(_logger)
      end

      private def class_definition(logger)
        Class.new do
          @@counter = 0
          @@logger = logger

          # @params kwargs[:sample] [Integer] output sample (if 10, output a log once every 10 requests)
          # @params kwargs[:extra_header_keys] [Array[String]] more header keys
          # @params kwargs[:format] :msgpack | :json
          # @params kwargs[:debug] if true, output debugging logs to stderr
          def initialize(app, **kwargs)
            @app = app
            @debug = kwargs[:debug] || false
            @sample = kwargs[:sample] || 10
            @extra_header_keys = kwargs[:extra_header_keys] || []
            @serializer = Serializer.new(kwargs[:format])
          end

          def call(env)
            @app.call(env).tap do |res|
              write(env, res)
            end
          end

          private

          def write(env, res)
            payload = nil
            if (@@counter % @sample).zero?
              payload = serialize(env, res)
              @@logger.write(payload + "\n")
            end
            @@counter += 1

            if @debug
              payload ||= serialize(env, res)
              $stderr.write("[Rreplay DEBUG]#{Time.now}: counter: #{@@counter}, sample: #{@sample}, payload: #{payload}")
            end
          end

          def serialize(env, res)
            uuid = SecureRandom.uuid
            time = Time.now.iso8601

            hash = {
              'uuid' => uuid,
              'time' => time,
              'request' => request_hash(env),
              'response' => response_hash(res)
            }
            @serializer.run(hash)
          end

          def response_hash(res)
            status, headers, body = res
            {
              'status' => status,
              'headers' => headers,
              'body' => body
            }
          end

          def request_hash(env)
            headers = {
              'content_type' => env['CONTENT_TYPE'],
              'cookie' => env['HTTP_COOKIE']
            }
            @extra_header_keys.each do |key|
              headers.merge!(key => env["HTTP_#{key}"])
            end

            {
              'path' => env['PATH_INFO'],
              'body' => env['rack.input'].gets,
              'query_strings' => env['QUERY_STRING'].empty? ? '' : '?' + env['QUERY_STRING'],
              'headers' => headers
            }
          end

        end
      end
    end

  end

  private

    class Serializer
      def initialize(format = :msgpack)
        case format
        when :msgpack then
          @runner = ->(obj) { MessagePack.pack(obj) }
        when :json then
          @runner = ->(obj) { JSON.dump(obj) }
        end
      end

      def run(obj)
        @runner.call(obj)
      end
    end

    class Deserializer
      def initialize(format = :msgpack)
        case format
        when :msgpack then
          @runner = ->(obj) { MessagePack.unpack(obj) }
        when :json then
          @runner = ->(obj) { JSON.parse(obj) }
        end
      end

      def run(obj)
        @runner.call(obj)
      end
    end
end
