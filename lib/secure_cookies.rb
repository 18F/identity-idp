# Reimplements SecureHeaders secure cookie functionality to make sure all cookies are secure
class SecureCookies
  COOKIE_SEPARATOR = "\n".freeze
  SECURE_COOKIE_ATTRIBUTES = ['; Secure', '; HttpOnly', '; SameSite=Lax'].freeze
  SECURE_COOKIE_REGEXES = SECURE_COOKIE_ATTRIBUTES.map { |attr| /#{attr}/i }

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if headers['Set-Cookie'].present?
      cookies = headers['Set-Cookie'].split(COOKIE_SEPARATOR)

      cookies.each do |cookie|
        next if cookie.blank?
        attributes = SECURE_COOKIE_ATTRIBUTES.zip(SECURE_COOKIE_REGEXES).reject do |_attr, regex|
          cookie.match?(regex)
        end.map(&:first)

        next if attributes.empty?

        cookie << attributes.join
      end

      headers['Set-Cookie'] = cookies.join(COOKIE_SEPARATOR)
    end

    [status, headers, body]
  end
end
