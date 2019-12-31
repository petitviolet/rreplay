module Rreplay
  class Debugger
    def initialize(logger, debug = true)
      @logger = logger
      @debug = !logger.nil? && debug
    end

    def out(&block)
      return unless @debug

      msg = block.call.then do |msg|
        case msg
        when Hash
          msg.merge({ time: Time.now.iso8601 }).to_json
        else
          "#{Time.now.iso8601} - #{block.call}"
        end
      end
      @logger.write("#{msg}\n")
    end
  end
end
