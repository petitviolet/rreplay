# frozen_string_literal: true

require 'securerandom'
require 'msgpack'
require 'json'
require 'time'

module Rack
  class Rreplay
    @@counter = 0

    # @params out [has #call or #write method] used for output request/response logs
    # @params kwargs[:sample] [Integer] output sample (if 10, output a log once every 10 requests)
    # @params kwargs[:extra_header_keys] [Array[String]] more header keys
    # @params kwargs[:format] :msgpack | :json
    def initialize(app, out = $stdout, **kwargs)
      @app = app
      @out = out.respond_to?(:call) ? ->(str) { out.call(str) } : ->(str) { out.write(str) }
      @sample = kwargs[:sample] || 10
      @extra_header_keys = kwargs[:extra_header_keys] || []
      @marshaller = Marshaller.new(kwargs[:format])
    end

    def call(env)
      @app.call(env).tap do |res|
        write(env, res)
      end
    end

    private

    def write(env, res)
      if (@@counter % @sample).zero?
        payload = marshal(env, res)
        @out.call(payload + "\n")
      end
      @@counter += 1
    end

    def marshal(env, res)
      uuid = SecureRandom.uuid
      time = Time.now.iso8601

      hash = {
        'uuid' => uuid,
        'time' => time,
        'request' => request_hash(env),
        'response' => response_hash(res)
      }
      @marshaller.run(hash)
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

  private

  class Marshaller
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
end
