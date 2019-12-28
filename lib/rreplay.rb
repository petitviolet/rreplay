require 'rack/rreplay'
require 'msgpack'
require 'json'
require 'net/http'
require 'uri'

module Rreplay
  class ReplayRunner
    def initialize(endpoint, target, format: :msgpack, logger: $stderr)
      @endpoint = endpoint
      @deserializer = Deserializer.new(format)
      @target = target
      @debugger = Debugger.new(logger)
    end

    def run
      file_names.each do |file_name|
        ::File.open(file_name) do |file|
          @debugger.out("Open file: #{file_name}")

          file.each_line do |line|
            next if line =~ /\A#/ # LogDevice's header

            request = @deserializer.run(line)["request"]
            http_call(request)
          end
        end
      end
    end

    private
      def file_names
        if ::File.directory?(@target)
          ::Dir.glob(::File.join(@target, "#{LOG_FILE_NAME}*"))
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

        Net::HTTP.start(uri.hostname, uri.port,
                        :use_ssl => uri.scheme == 'https') {|http|
          response = http.request(request)
        }
      end
  end

  private

  class Debugger
    def initialize(logger, debug = true)
      @logger = logger
      @debug = !logger.nil? && debug
    end

    def out(msg)
      @logger.write("#{Time.now.iso8601} - #{msg}") if @debug
    end
  end

  class Deserializer
    def initialize(format = :msgpack)
      case format.to_sym
      when :msgpack then
        @runner = ->(obj) { MessagePack.unpack(obj) }
      when :json then
        @runner = ->(obj) { JSON.parse(obj) }
      else
        raise "Unknown format '#{format}'"
      end
    end

    def run(obj)
      @runner.call(obj)
    end
  end
end