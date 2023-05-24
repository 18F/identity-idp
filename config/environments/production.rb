Rails.application.configure do
  config.cache_classes = true
  config.cache_store = :redis_cache_store, { url: IdentityConfig.store.redis_url }
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.force_ssl = true

  config.asset_host = proc do |_source, request|
    # we want precompiled assets to have domain-agnostic URLs
    # and request is nil during asset precompilation
    (IdentityConfig.store.asset_host.presence || IdentityConfig.store.domain_name) if request
  end
  config.assets.compile = false
  config.assets.digest = true
  config.assets.gzip = false
  config.i18n.fallbacks = true
  config.active_support.deprecation = :notify
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = {
    host: IdentityConfig.store.domain_name,
    protocol: 'https',
  }
  config.action_mailer.asset_host = IdentityConfig.store.asset_host.presence ||
                                    IdentityConfig.store.mailer_domain_name
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = if IdentityConfig.store.disable_email_sending
                                           :test
                                         else
                                           :ses
                                         end

  if IdentityConfig.store.rails_mailer_previews_enabled
    config.action_mailer.show_previews = true
    config.action_mailer.preview_path = Rails.root.join('spec/mailers/previews')
  end

  routes.default_url_options[:protocol] = :https

  # turn off IP spoofing protection since the network configuration in the production environment
  # creates false positive results.
  config.action_dispatch.ip_spoofing_check = false

  if IdentityConfig.store.log_to_stdout
    Rails.logger = Logger.new(STDOUT)
    config.logger = ActiveSupport::Logger.new(STDOUT)
  end
  config.log_level = :info
  config.lograge.ignore_actions = ['Users::SessionsController#active']
end
