require 'logger'
require_relative '../../lib/rack/rreplay'
require_relative './app'

use Rack::Rreplay, $stdout, sample: 1, extra_header_keys: %w[ACCESS_TOKEN], format: :json
run App
