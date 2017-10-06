require 'rack/headers_filter'

# Expands on Rack::HeadersFilter to delete additional headers
class HeadersFilter
  HEADERS_TO_DELETE = Rack::HeadersFilter::SENSITIVE_HEADERS

  def initialize(app)
    @app = app
  end

  def call(env)
    HEADERS_TO_DELETE.each { |header| env.delete(header) }
    app.call(env)
  end

  private

  attr_reader :app
end
