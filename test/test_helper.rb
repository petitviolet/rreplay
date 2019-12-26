$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rreplay"

require "minitest/autorun"
require 'json_expressions/minitest'
require 'rack/test'
require 'timecop'
