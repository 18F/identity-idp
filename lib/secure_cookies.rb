# frozen_string_literal: true

# Reimplements SecureHeaders secure cookie functionality to make sure all cookies are secure
class SecureCookies
  SECURE_REGEX = /; Secure/i
  HTTP_ONLY_REGEX = /; HttpOnly/i
  SAME_SITE_REGEX = /; SameSite/i

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    cookies = headers[Rack::SET_COOKIE]
    if cookies
      headers[Rack::SET_COOKIE] = Array(cookies).map do |cookie|
        return cookie if cookie.blank?

        cookie << '; Secure' if env['HTTPS'] == 'on' && !cookie.match?(SECURE_REGEX)
        cookie << '; HttpOnly' if !cookie.match?(HTTP_ONLY_REGEX)
        cookie << '; SameSite=Lax' if !cookie.match?(SAME_SITE_REGEX)

        cookie
      end
    end

    [status, headers, body]
  end
end
