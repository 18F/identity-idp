Sidekiq::Logging.logger.level = Logger::WARN

Sidekiq.configure_server do |config|
  config.redis = { url: Figaro.env.redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Figaro.env.redis_url }
end
