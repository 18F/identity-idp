Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.i18n.raise_on_missing_translations = true

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  config.action_mailer.default_url_options = {
    host: IdentityConfig.store.domain_name,
    protocol: ENV['HTTPS'] == 'on' ? 'https' : 'http',
  }
  config.action_mailer.asset_host = IdentityConfig.store.mailer_domain_name
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.show_previews = IdentityConfig.store.rails_mailer_previews_enabled
  config.action_mailer.delivery_method = IdentityConfig.store.development_mailer_deliver_method
  if IdentityConfig.store.development_mailer_deliver_method == :letter_opener
    config.action_mailer.perform_deliveries = true
  end

  routes.default_url_options[:protocol] = 'https' if ENV['HTTPS'] == 'on'

  config.lograge.ignore_actions = ['Users::SessionsController#active']

  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}",
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
    config.public_file_server.headers = {
      'Cache-Control' => 'public, no-cache, must-revalidate',
      'Vary' => '*',
    }
  end

  # Bullet gem config
  config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
  end
end
