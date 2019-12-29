module Rreplay
  class Debugger
    def initialize(logger, debug = true)
      @logger = logger
      @debug = !logger.nil? && debug
    end

    def out(&block)
      return unless @debug

      @logger.write("#{Time.now.iso8601} - #{block.call}\n")
    end
  end
end
