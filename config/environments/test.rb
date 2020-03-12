Rails.application.configure do
  config.active_job.queue_adapter = :test
  config.cache_classes = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = false
  config.action_controller.allow_forgery_protection = false
  config.active_support.test_order = :random
  config.active_support.deprecation = :stderr
  config.action_view.raise_on_missing_translations = true

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: Figaro.env.domain_name }
  config.action_mailer.asset_host = Figaro.env.mailer_domain_name
  config.action_mailer.default_options = { from: Figaro.env.email_from }

  config.assets.debug = true

  config.action_controller.asset_host = if ENV.key?('RAILS_ASSET_HOST')
                                          ENV['RAILS_ASSET_HOST']
                                        else
                                          '//'
                                        end

  config.assets.digest = ENV.key?('RAILS_DISABLE_ASSET_DIGEST') ? false : true

  config.middleware.use RackSessionAccess::Middleware
  config.lograge.enabled = true

  config.after_initialize do
    # Having bullet enabled in the test environment causes issues with unit
    # tests that may not make user of eager loaded values. We disable it by
    # default here and then re-enable it in feature tests.
    Bullet.enable = false
    Bullet.bullet_logger = true
    Bullet.raise = true
    Bullet.add_whitelist(
      type: :n_plus_one_query, class_name: 'User', association: :phone_configurations,
    )
    Bullet.add_whitelist(
      type: :n_plus_one_query, class_name: 'User', association: :email_addresses,
    )
  end

  config.active_support.test_order = :random
end
