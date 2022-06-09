# frozen_string_literal: true

# A middleware that helps us migrate the name of our session_store cookie key
# Phase 1
# - update the session_store.rb to read from the new key
# - this middleware copies "Cookie" headers with the old key to the new key (forward compat)
# - this middleware copies "Set-Cookie" headers with the new key to the old key (backward compat)
# Phase 2
# - drop this middleware!
class SessionStoreMigration
  OLD_KEY = '_upaya_session'
  NEW_KEY = '_identity_idp_session'
  COOKIE_SEPARATOR = "\n"

  def initialize(app)
    @app = app
  end

  def call(env)
    process_in_headers!(env)

    status, out_headers, body = @app.call(env)

    [status, process_out_headers!(out_headers), body]
  end

  def process_in_headers!(env)
    cookie_str = env[Rack::HTTP_COOKIE]

    if cookie_str.include?(OLD_KEY) && !cookie_str.include?(NEW_KEY)
      cookies = Rack::Utils.parse_cookies_header(cookie_str)

      updated_cookie_str = cookie_str + "; #{NEW_KEY}=#{cookies[OLD_KEY]}"

      env[Rack::HTTP_COOKIE] = updated_cookie_str

      Rails.logger.info({ name: 'session_store_migration', cookie: 'old' }.to_json)
    else
      Rails.logger.info({ name: 'session_store_migration', cookie: 'new' }.to_json)
    end
  end

  def process_out_headers!(headers)
    if (cookie_header = headers[Rack::SET_COOKIE]).present?
      cookies = cookie_header.split(COOKIE_SEPARATOR)

      new_key_set = cookies.find { |cookie| cookie.start_with?(NEW_KEY) }
      cookies << new_key_set.sub(NEW_KEY, OLD_KEY) if new_key_set.present?

      headers[Rack::SET_COOKIE] = cookies.join(COOKIE_SEPARATOR)
    end

    headers
  end
end
