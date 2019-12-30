require "test_helper"

class RreplayTest < Minitest::Unit::TestCase
  include Rack::Test::Methods
  DEFAULT_STATUS = 200
  DEFAULT_HEADERS = {
    'Content-Type' => 'application/json',
    'ACCESS_TOKEN' => 'awesome token',
    'X-ACCESS-TOKEN' => 'x-token',
    'Cookie' => 'cookie_key=cookie_value',
  }
  DEFAULT_RESPONSE_BODY = ["Hello, World!"]

  # @param env [Hash] env['YOUR_HEADER'] = 'nice'
  # @param response [Hash] {:method, :url, :headers, :body}
  def run_request(env: {}, response: {}, &b)
    app = lambda { |_|
      [
        response[:status] || DEFAULT_STATUS,
        response[:headers] || DEFAULT_HEADERS,
        response[:body] || DEFAULT_RESPONSE_BODY,
      ]
    }
    rack = b.call app
    Rack::MockRequest.new(rack).request(env[:method], env[:path] || '/', env)
  end

  def test_request_and_response_is_recorded
    output = StringIO.new
    Timecop.freeze(Time.now)
    time = Time.now.iso8601

    expected = {
      time: time,
      uuid: String,
      response_time: String,
      request: {
        method: 'GET',
        body: nil,
        headers: {
          'ACCESS_TOKEN' => 'token',
          'X-ACCESS-TOKEN' => 'x-token',
          :'content-type' => nil,
          :'user-agent' => nil,
          cookie: nil
        },
        path: '/',
        query_strings: ''
      },
      response: {
        body: DEFAULT_RESPONSE_BODY.join(''),
        headers: DEFAULT_HEADERS,
        status: DEFAULT_STATUS
      },
    }
     run_request(env: {'ACCESS_TOKEN' => 'token', 'X-ACCESS-TOKEN' => 'x-token'}, response: {}) do |app|
      Rack::Rreplay.Middleware(directory: nil, format: :json,  logger: output)
        .new(app, sample: 1, extra_header_keys: %w[ACCESS_TOKEN X-ACCESS-TOKEN])
    end

    assert_json_match(expected, JSON.parse(output.string))
  end
end
