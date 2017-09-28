require 'rack/headers_filter'

# Expands on Rack::HeadersFilter to delete additional headers
class HeadersFilter
  HEADERS_TO_DELETE = Rack::HeadersFilter::SENSITIVE_HEADERS + %w[
    HTTP_HOST
  ]

  def initialize(app)
    @app = app
  end

  def call(env)
    HEADERS_TO_DELETE.each { |header| env.delete(header) }
    ascii_encode_headers(env)
    app.call(env)
  end

  private

  def ascii_encode_headers(env)
    headers = env.select { |key, _value| key.starts_with? 'HTTP_' }
    headers.each do |header, value|
      env[header] = value.encode('ascii-8bit', invalid: :replace, undef: :replace, replace: '?')
    end
  end

  attr_reader :app
end
