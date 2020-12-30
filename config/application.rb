require_relative 'boot'

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'

require_relative '../lib/upaya_log_formatter'
require_relative '../lib/app_config'
require_relative '../lib/fingerprinter'
require_relative '../lib/secure_headers_whitelister'

Bundler.require(*Rails.groups)

APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    AppConfig.setup(YAML.safe_load(File.read(Rails.root.join('config', 'application.yml'))))

    config.load_defaults '6.1'
    config.active_record.belongs_to_required_by_default = false
    config.assets.unknown_asset_fallback = true

    config.active_job.queue_adapter = 'inline'
    config.time_zone = 'UTC'

    # Generate CSRF tokens that are encoded in URL-safe Base64.
    #
    # This change is not backwards compatible with earlier Rails versions.
    # It's best enabled when your entire app is migrated and stable on 6.1.
    Rails.application.config.action_controller.urlsafe_csrf_tokens = false

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = AppConfig.env.available_locales.try(:split, ' ') || %w[en]
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true
    config.action_dispatch.cookies_same_site_protection = :lax
    config.action_dispatch.default_headers = {
      'X-Frame-Options' => 'DENY',
    }

    routes.default_url_options[:host] = AppConfig.env.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = AppConfig.env.email_from
        mail.display_name = AppConfig.env.email_from_display_name
      end.to_s,
    }

    config.lograge.custom_options = lambda do |event|
      event.payload[:timestamp] = Time.zone.now.iso8601
      event.payload[:uuid] = SecureRandom.uuid
      event.payload[:pid] = Process.pid
      event.payload.except(:params, :headers)
    end

    # Use a custom log formatter to get timestamp
    config.log_formatter = Upaya::UpayaLogFormatter.new

    require 'headers_filter'
    require 'httponly_cookies'
    config.middleware.insert_before 0, HeadersFilter
    config.middleware.insert_before 0, HttponlyCookies
    require 'utf8_sanitizer'
    config.middleware.use Utf8Sanitizer

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          next if source == AppConfig.env.domain_name

          ServiceProvider.pluck(:redirect_uris).flatten.compact.find do |uri|
            split_uri = uri.split('//')
            protocol = split_uri[0]
            domain = split_uri[1].split('/')[0] if split_uri.size > 1
            source == "#{protocol}//#{domain}"
          end.present?
        end
        resource '/.well-known/openid-configuration', headers: :any, methods: [:get]
        resource '/api/openid_connect/certs', headers: :any, methods: [:get]
        resource '/api/openid_connect/token',
                 credentials: true,
                 headers: :any,
                 methods: %i[post options]
        resource '/api/openid_connect/userinfo', headers: :any, methods: [:get]
      end
    end

    if AppConfig.env.enable_rate_limiting == 'true'
      config.middleware.use Rack::Attack
    else
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end
  end
end
