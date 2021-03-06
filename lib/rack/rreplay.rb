# frozen_string_literal: true

require 'securerandom'
require 'msgpack'
require 'json'
require 'time'
require_relative '../rreplay'
require_relative '../rreplay/debugger'
require_relative '../rreplay/format'

module Rack
  class Rreplay

    class << self
      # ==sample
      # use Rack::Rreplay.Middleware(directory: './tmp', format: :json),
      #    sample: 5, extra_header_keys: %w[ACCESS_TOKEN], debug: true
      #
      # @param directory [String] rreplay dump file directory, and if nil, use logger as debug
      # @param logger [IO] if directory is nil, logger can be given
      def Middleware(directory:, format: :msgpack, logger: nil)
        if directory.nil? && logger.nil?
          raise "Invalid arguments. directory: or logger: must be given", ArgumentError
        end
        format = ::Rreplay::Format.of(format)
        if directory
          ::FileUtils.mkdir_p(directory)
          logger = ::Logger::LogDevice.new(
            ::File.join(directory, ::Rreplay::LOG_FILE_NAME_PREFIX + format.file_suffix),
            shift_age: 10,
            shift_size: 1048576,
            binmode: format.is_binary?
          )
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
            start_time = Time.now
            @app.call(env).tap do |res|
              write(start_time, env, res)
            end
          end

          private

          def write(start_time, env, res)
            payload = nil
            if (@@counter % @sample).zero?
              payload = serialize(start_time, env, res)
              @@logger.write(payload + "\n")
            end
            @@counter += 1

            @debugger.out do
              payload ||= serialize(start_time, env, res)
              "[Rreplay DEBUG]#{Time.now}: counter: #{@@counter}, sample: #{@sample}, payload: #{payload}"
            end
          end

          def serialize(start_time, env, res)
            uuid = SecureRandom.uuid
            end_time = Time.now

            hash = {
              'uuid' => uuid,
              'time' => end_time.iso8601,
              'response_time' => (end_time - start_time).to_s,
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
              'body' => response_body(body),
            }
          end

          def response_body(body)
            return body unless body.respond_to?(:each)

            [].tap do |b|
              body.each { |content| b << content }
            end.join('')
          end

          def request_hash(env)
            headers = {
              'content-type' => env['CONTENT_TYPE'],
              'cookie' => env['HTTP_COOKIE'],
              'user-agent' => env['HTTP_USER_AGENT'],
            }
            @extra_header_keys.each do |key|
              headers.merge!(extra_header(env, key))
            end

            {
              'method' => env['REQUEST_METHOD'],
              'path' => env['PATH_INFO'],
              'body' => env['rack.input'].gets,
              'query_strings' => env['QUERY_STRING'].empty? ? '' : '?' + env['QUERY_STRING'],
              'headers' => headers
            }
          end

          def extra_header(env, key)
            { key =>
                env[key] ||
                  env["HTTP_#{key}"] ||
                  env[key.upcase] ||
                  env[key.upcase.gsub('-', '_')] ||
                  env["HTTP_#{key.upcase}"] ||
                  env["HTTP_#{key.upcase.gsub('-', '_')}"]
            }
          end

        end
      end
    end

    private

  end
end
