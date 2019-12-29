require 'logger'
require_relative '../../lib/rack/rreplay'
require_relative './app'

use Rack::Rreplay.Middleware(directory: './tmp', format: :json),
    { sample: 1, extra_header_keys: %w[ACCESS_TOKEN], debug: true }
run App
