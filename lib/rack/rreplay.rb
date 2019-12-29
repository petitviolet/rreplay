# frozen_string_literal: true

require 'securerandom'
require 'msgpack'
require 'json'
require 'time'
require_relative '../rreplay/debugger'
require_relative '../rreplay/format'

module Rack
  class Rreplay
    LOG_FILE_NAME_PREFIX = 'rreplay.log'

    class << self
      # ==sample
      # use Rack::Rreplay.Middleware(directory: './tmp'),
      #    sample: 5, extra_header_keys: %w[ACCESS_TOKEN], format: :json, debug: true
      #
      # @param directory [String] rreplay dump file directory, and if nil, use logger as debug
      # @param logger [IO] if directory is nil, logger can be given
      def Middleware(directory:, format: :msgpack, logger: nil)
        format = ::Rreplay::Format.of(format)
        if directory
          ::FileUtils.mkdir_p(directory)
          logger = ::Logger::LogDevice.new(
            ::File.join(directory, LOG_FILE_NAME_PREFIX + format.file_suffix),
            shift_age: 10,
            shift_size: 1048576,
          )
        else
          logger = logger
        end
        class_definition(logger, format)
      end

      private def class_definition(logger, format)
        Class.new do
          @@counter = 0
          @@logger = logger
          @@format = format

          # @params kwargs[:sample] [Integer] output sample (if 10, output a log once every 10 requests)
          # @params kwargs[:extra_header_keys] [Array[String]] more header keys
          # @params kwargs[:format] :msgpack | :json
          # @params kwargs[:debug] if true, output debugging logs to stderr
          def initialize(app, **kwargs)
            @app = app
            @debugger = ::Rreplay::Debugger.new($stderr, kwargs[:debug] || false)
            @sample = kwargs[:sample] || 10
            @extra_header_keys = kwargs[:extra_header_keys] || []
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

            @debugger.out do
              payload ||= serialize(env, res)
              "[Rreplay DEBUG]#{Time.now}: counter: #{@@counter}, sample: #{@sample}, payload: #{payload}"
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
            @@format.serializer.call(hash)
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
              'content-type' => env['CONTENT_TYPE'],
              'cookie' => env['HTTP_COOKIE'],
              'user-agent' => env['HTTP_USER_AGENT'],
            }
            @extra_header_keys.each do |key|
              headers.merge!(key => env["HTTP_#{key}"])
            end

            {
              'method' => env['REQUEST_METHOD'],
              'path' => env['PATH_INFO'],
              'body' => env['rack.input'].gets,
              'query_strings' => env['QUERY_STRING'].empty? ? '' : '?' + env['QUERY_STRING'],
              'headers' => headers
            }
          end

        end
      end
    end

    private

  end
end
