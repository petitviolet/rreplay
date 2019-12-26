require "test_helper"

class RreplayTest < Minitest::Unit::TestCase
  include Rack::Test::Methods
  DEFAULT_STATUS = 200
  DEFAULT_HEADERS = {
    'Content-Type' => 'application/json',
    'ACCESS_TOKEN' => 'awesome token',
    'Cookie' => 'cookie_key=cookie_value',
  }
  DEFAULT_RESPONSE_BODY = ["Hello, World!"]

  # env.{:method, :url, :headers, :body}
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
      request: {
        body: nil,
        headers: {
          ACCESS_TOKEN: nil,
          content_type: nil,
          cookie: nil
        },
        path: '/',
        query_strings: ''
      },
      response: {
        body: DEFAULT_RESPONSE_BODY,
        headers: DEFAULT_HEADERS,
        status: DEFAULT_STATUS
      },
    }
    run_request(env: {}, response: {}) do |app|
      Rack::Rreplay.new(app, output, sample: 1, extra_header_keys: %w[ACCESS_TOKEN], format: :json)
    end

    assert_json_match(expected, JSON.parse(output.string))
  end
end
