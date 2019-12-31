require 'rack/rreplay'
require 'msgpack'
require 'json'
require 'net/http'
require 'uri'
require_relative './debugger'
require_relative './format'

module Rreplay
  class ReplayRunner
    def initialize(endpoint, target, format: :msgpack, debug: false)
      @http = Http.new(endpoint)
      @format = Rreplay::Format.of(format)
      @target = target
      @debugger = Debugger.new($stderr, debug)
    end

    def run
      file_names.each do |file_name|
        ::File.open(file_name) do |file|
          @debugger.out { "Open file: #{file_name}" }

          file.each_line do |line|
            next if line.start_with?('#') # LogDevice's header
            line.chomp!
            record = deserialize(line)

            result = @http.call(record['request'])
            @debugger.out {
              Output.new.call(record, result)
            }
          end
        end
      end
    end

    private

      def file_names
        if ::File.directory?(@target)
          ::Dir.glob(::File.join(@target,
                                 ::Rreplay::LOG_FILE_NAME_PREFIX + @format.file_suffix + "*"))
        else
          Array(@target)
        end
      end

      def deserialize(line)
        @format.deserializer.call(line)
      rescue => e
        raise "Failed to deserialize. err = #{e.inspect}, line = #{line}", e
      end

  end

  private

    class Output
      def initialize
      end

      # @param record [Hash]
      # @param result [Http::Result]
      def call(record, result)
        response_json = {
          status: result.response.code,
          headers: record['response']['headers'].reduce({}) do |acc, (key, _)|
            acc.merge({key => result.response[key]})
          end,
          body: Array(result.response.body),
        }

        build_string(record, result.response_time, response_json)
      end

      private

        def build_string(record, response_time, actual_response)
          <<~EOF
            #{record['uuid']}:
            * request:
              #{record['request']}
            * response(actual):
              #{response_time} sec
              #{actual_response}
            * response(recorded):
              #{record['response_time']} sec
              #{record['response']}
          EOF
        end
    end

    class Http
      Result = Struct.new(:response, :response_time)

      def initialize(endpoint)
        @endpoint = endpoint
      end

      def call(orig_request)
        uri = URI(::File.join(@endpoint, orig_request['path'], orig_request['query_strings']))
        body = orig_request['body']
        headers = orig_request['headers']
        headers.merge!({ 'User-Agent': 'RreplayRunner' })

        request_clazz = case orig_request['method'].upcase
                        when 'GET'
                          Net::HTTP::Get
                        when 'POST'
                          Net::HTTP::Post
                        when 'PUT'
                          Net::HTTP::Put
                        when 'PATCH'
                          Net::HTTP::Patch
                        when 'DELETE'
                          Net::HTTP::Delete
                        else
                          # ignore
                          return
                        end
        request = request_clazz.new(uri, headers).tap do |req|
          req.body = body
        end

        start_time = Time.now
        response = Net::HTTP.start(uri.hostname, uri.port,
                                   :use_ssl => uri.scheme == 'https') { |http|
          http.request(request)
        }
        Result.new(response, Time.now - start_time)
      end
    end
end
