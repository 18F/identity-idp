class HttponlyCookies
  HEADERS_TO_DELETE = Rack::HeadersFilter::SENSITIVE_HEADERS

  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)
    status, headers, response = app.call(env)

    set_httponly_cookies!(headers)
    [status, headers, response]
  end

  def set_httponly_cookies!(headers)
    if cookies = headers["Set-Cookie"]
      headers["Set-Cookie"] = cookies.split("\n").map do |cookie|
        cookie << "; HttpOnly"
      end.join("\n")
    end
  end

  private

  attr_reader :app
end
