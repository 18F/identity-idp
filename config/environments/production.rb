Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.asset_host = Figaro.env.domain_name
  config.action_controller.perform_caching = true
  config.serve_static_files = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.js_compressor = :uglifier
  config.assets.compile = false
  config.assets.digest = true
  config.i18n.fallbacks = true
  config.active_support.deprecation = :notify
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = {
    host: Figaro.env.domain_name,
    protocol: 'https',
  }
  config.action_mailer.asset_host = Figaro.env.mailer_domain_name
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_options = { from: Figaro.env.email_from }
  config.action_mailer.delivery_method = if Figaro.env.disable_email_sending == 'true'
                                           :test
                                         elsif Figaro.env.mandrill_api_token.present?
                                           :mandrill
                                         else
                                           :ses
                                         end

  routes.default_url_options[:protocol] = :https

  # turn off IP spoofing protection since the network configuration in the production environment
  # creates false positive results.
  config.action_dispatch.ip_spoofing_check = false

  config.log_level = :info
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['Users::SessionsController#active']
  config.lograge.formatter = Lograge::Formatters::Json.new
end
