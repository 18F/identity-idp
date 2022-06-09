require 'session_encryptor'
require 'legacy_session_encryptor'
require 'session_encryptor_error_handler'

Rails.application.config.session_store(
  :redis_session_store,
  # "Upaya" is a legacy code name for the project. This should be renamed. See: LG-6584
  key: '_upaya_session',
  redis: {
    driver: :hiredis,

    # cookie expires with browser close
    expire_after: nil,

    # Redis expires session after N minutes
    ttl: IdentityConfig.store.session_timeout_in_minutes.minutes,

    key_prefix: "#{IdentityConfig.store.domain_name}:session:",
    url: IdentityConfig.store.redis_url,
  },
  on_session_load_error: SessionEncryptorErrorHandler,
  serializer: SessionEncryptor.new,
)
