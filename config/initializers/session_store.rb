require 'session_encryptor'
require 'legacy_session_encryptor'
require 'session_encryptor_error_handler'

APPLICATION_SESSION_COOKIE_KEY = '_identity_idp_session'.freeze

Rails.application.config.session_store(
  :redis_session_store,
  key: APPLICATION_SESSION_COOKIE_KEY,
  redis: {
    # cookie expires with browser close
    expire_after: nil,

    read_public_id: IdentityConfig.store.redis_session_read_public_id,
    write_public_id: IdentityConfig.store.redis_session_write_public_id,
    read_private_id: IdentityConfig.store.redis_session_read_private_id,
    write_private_id: IdentityConfig.store.redis_session_write_private_id,

    # Redis expires session after N minutes
    ttl: IdentityConfig.store.session_timeout_in_minutes.minutes,

    key_prefix: "#{IdentityConfig.store.domain_name}:session:",
    client_pool: REDIS_POOL,
  },
  on_session_load_error: SessionEncryptorErrorHandler,
  on_redis_down: proc { |error| raise error },
  serializer: SessionEncryptor.new,
)
