module Rreplay
  class Debugger
    def initialize(logger, debug = true)
      @logger = logger
      @debug = !logger.nil? && debug
    end

    def out(msg = nil)
      return unless @debug
      if block_given?
        msg = yield
      end

      @logger.write("#{Time.now.iso8601} - #{msg}")
    end
  end
end
