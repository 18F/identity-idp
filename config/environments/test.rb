Rails.application.configure do
  config.active_job.queue_adapter = :test
  config.cache_classes = false
  config.action_view.cache_template_loading = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=600' }
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = false
  config.action_controller.allow_forgery_protection = false
  config.active_support.test_order = :random
  config.active_support.deprecation = :stderr
  config.assets.gzip = false
  config.i18n.raise_on_missing_translations = true

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: IdentityConfig.store.domain_name }
  config.action_mailer.asset_host = IdentityConfig.store.mailer_domain_name

  config.assets.debug = false

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []
  #
  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  config.action_controller.asset_host = ENV['RAILS_ASSET_HOST'] if ENV.key?('RAILS_ASSET_HOST')

  config.assets.digest = ENV.key?('RAILS_DISABLE_ASSET_DIGEST') ? false : true

  config.middleware.use RackSessionAccess::Middleware

  config.after_initialize do
    # Having bullet enabled in the test environment causes issues with unit
    # tests that may not make user of eager loaded values. We disable it by
    # default here and then re-enable it in feature tests.
    Bullet.enable = false
    Bullet.bullet_logger = true
    Bullet.raise = true
    [
      :phone_configurations,
      :piv_cac_configurations,
      :auth_app_configurations,
      :backup_code_configurations,
      :webauthn_configurations,
      :email_addresses,
      :proofing_component,
      :account_reset_request,
    ].each do |association|
      Bullet.add_safelist(type: :n_plus_one_query, class_name: 'User', association: association)
    end
  end

  config.active_support.test_order = :random
end
