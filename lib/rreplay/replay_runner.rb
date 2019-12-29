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
      @endpoint = endpoint
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

            begin
              record = @format.deserializer.call(line)
            rescue => e
              raise "Failed to deserialize. err = #{e.inspect}, line = #{line}", e
            end
            request = record["request"]
            result, response_time = http_call(request)
            @debugger.out {
              response_json = {
                status: result.code,
                headers: record['response']['headers'].reduce({}) do |acc, (key, _)|
                  acc.merge({key => result[key]})
                end,
                body: Array(result.body),
              }
              <<~EOF
              #{record['uuid']}:
              * request:
                #{request}
              * response(actual):
                #{response_time} sec
                #{response_json}
              * response(recorded):
                #{record['response_time']} sec
                #{record['response']}
              EOF
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


      def http_call(orig_request)
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
        [response, Time.now - start_time]
      end
  end

  private

end
