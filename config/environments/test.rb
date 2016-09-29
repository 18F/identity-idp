Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.active_job.queue_adapter = :test

  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static file server for tests with Cache-Control for performance.
  config.serve_static_files   = true
  config.static_cache_control = 'public, max-age=3600'

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: Figaro.env.domain_name }
  config.action_mailer.asset_host = Figaro.env.mailer_domain_name
  config.action_mailer.default_options = { from: Figaro.env.email_from }

  if ENV.key?('RAILS_ASSET_HOST')
    config.action_controller.asset_host = ENV['RAILS_ASSET_HOST']
  end

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # For testing session variables in Capybara specs
  config.middleware.use RackSessionAccess::Middleware

  config.lograge.enabled = true
  config.lograge.custom_options = ->(event) { event.payload }

  # Bullet gem config
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = true
  end

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random
end
