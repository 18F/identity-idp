Sidekiq::Logging.logger.level = Logger::WARN

Sidekiq.configure_server do |config|
  config.redis = { url: Figaro.env.redis_url }

  # NOTE: Sidekiq does not run middleware in tests by default. Make sure to also add
  # middleware to spec/rails_helper.rb to run in tests as well
  config.server_middleware do |chain|
    chain.add WorkerHealthChecker::Middleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: Figaro.env.redis_url }
end
