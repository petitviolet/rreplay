#!/usr/bin/env ruby

require "bundler/setup"
require "rreplay"

def main(endpoint, target, format: :msgpack, logger: $stderr)
  runner = Rreplay::ReplayRunner.new(endpoint, target, format: format, logger: logger)
  runner.run
end

endpoint = ARGV.shift
target = ARGV.shift
format = ARGV.shift || :msgpack

main(endpoint, target, format: format)
