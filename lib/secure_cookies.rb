class SecureCookies
  COOKIE_SEPARATOR = "\n".freeze
  SECURE_COOKIE_ATTRIBUTES = ['; Secure', '; HttpOnly', '; SameSite=Lax'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if headers['Set-Cookie'].present?
      cookies = headers['Set-Cookie'].split(COOKIE_SEPARATOR)

      cookies.each do |cookie|
        attributes = SECURE_COOKIE_ATTRIBUTES.reject { |attr| attr if cookie.match?(/#{attr}/i) }

        next if cookie.blank?
        next if attributes.empty?

        cookie << attributes.join
      end

      headers['Set-Cookie'] = cookies.join(COOKIE_SEPARATOR)
    end

    [status, headers, body]
  end
end
