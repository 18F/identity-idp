require 'session_encryptor'

options = {
  key: '_upaya_session',
  redis: {
    driver: :hiredis,

    # cookie expires with browser close
    expire_after: nil,

    # Redis expires session after N minutes
    ttl: Figaro.env.session_timeout_in_minutes.to_i.minutes,

    key_prefix: "#{Figaro.env.domain_name}:session:",
    url: Figaro.env.redis_url,
  },
  on_session_load_error: SessionEncryptorErrorHandler,
  serializer: SessionEncryptor.new,
}

Rails.application.config.session_store :redis_session_store, options
