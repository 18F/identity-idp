# Reimplements SecureHeaders secure cookie functionality to make sure all cookies are secure
class SecureCookies
  COOKIE_SEPARATOR = "\n".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if (cookie_header = headers['Set-Cookie']).present?
      cookies = cookie_header.split(COOKIE_SEPARATOR)

      cookies.each do |cookie|
        next if cookie.blank?

        cookie << '; Secure' if env['HTTPS'] == 'on' && !cookie.match?(/; Secure/i)
        cookie << '; HttpOnly' if !cookie.match?(/; HttpOnly/i)
        cookie << '; SameSite=Lax' if !cookie.match?(/; SameSite/i)
      end

      headers['Set-Cookie'] = cookies.join(COOKIE_SEPARATOR)
    end

    [status, headers, body]
  end
end
