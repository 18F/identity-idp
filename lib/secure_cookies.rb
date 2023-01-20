# frozen_string_literal: true

# Reimplements SecureHeaders secure cookie functionality to make sure all cookies are secure
class SecureCookies
  COOKIE_SEPARATOR = "\n"
  SECURE_REGEX = /; Secure/i
  HTTP_ONLY_REGEX = /; HttpOnly/i
  SAME_SITE_REGEX = /; SameSite/i

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if (cookie_header = headers['Set-Cookie']).present?
      cookies = cookie_header.split(COOKIE_SEPARATOR)

      cookies.each do |cookie|
        next if cookie.blank?

        cookie << '; Secure' if env['HTTPS'] == 'on' && !cookie.match?(SECURE_REGEX)
        cookie << '; HttpOnly' if !cookie.match?(HTTP_ONLY_REGEX)
        cookie << '; SameSite=Lax' if !cookie.match?(SAME_SITE_REGEX)
      end

      headers['Set-Cookie'] = cookies.join(COOKIE_SEPARATOR)
    end

    [status, headers, body]
  end
end
