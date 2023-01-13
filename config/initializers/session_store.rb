require 'session_encryptor'
require 'legacy_session_encryptor'
require 'session_encryptor_error_handler'

Rails.application.config.session_store(
  :redis_session_store,
  key: '_identity_idp_session',
  redis: {
    # cookie expires with browser close
    expire_after: nil,

    # Redis expires session after N minutes
    ttl: IdentityConfig.store.session_timeout_in_minutes.minutes,

    key_prefix: "#{IdentityConfig.store.domain_name}:session:",
    client: REDIS_SESSION_POOL_WRAPPER,
  },
  on_session_load_error: SessionEncryptorErrorHandler,
  on_redis_down: proc { |error, _env, _sid| raise error },
  serializer: SessionEncryptor.new,
)
