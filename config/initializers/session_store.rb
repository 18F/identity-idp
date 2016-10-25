options = {
  key: '_upaya_session',
  redis: {
    driver: :hiredis,
    expire_after: Figaro.env.session_timeout_in_minutes.to_i.minutes,
    key_prefix: "#{Figaro.env.domain_name}:session:",
    url: Figaro.env.redis_url
  },
  serializer: :marshal
}

Rails.application.config.session_store :redis_session_store, options
