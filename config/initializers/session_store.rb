require 'session_encryptor'
require 'legacy_session_encryptor'

APPLICATION_SESSION_COOKIE_KEY = '_identity_idp_session'.freeze

Rails.application.config.session_store(
  :redis_session_store,
  key: APPLICATION_SESSION_COOKIE_KEY,
  # cookie expires with browser close
  expire_after: nil,
  redis: {
    read_public_id: IdentityConfig.store.redis_session_read_public_id,
    write_public_id: IdentityConfig.store.redis_session_write_public_id,
    read_private_id: IdentityConfig.store.redis_session_read_private_id,
    write_private_id: IdentityConfig.store.redis_session_write_private_id,

    # Redis expires session after N minutes
    ttl: IdentityConfig.store.session_timeout_in_minutes.minutes,

    key_prefix: "#{IdentityConfig.store.domain_name}:session:",
    client_pool: REDIS_POOL,
  },
  on_session_load_error: proc { |error, _sid| raise error },
  on_redis_down: proc { |error| raise error },
  serializer: SessionEncryptor.new,
)
