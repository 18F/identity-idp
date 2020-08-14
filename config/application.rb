require File.expand_path('../boot', __FILE__)
require 'rails/all'
require_relative '../lib/upaya_log_formatter'

Bundler.require(*Rails.groups)

APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    config.active_job.queue_adapter = 'inline'
    config.autoload_paths << Rails.root.join('app', 'mailers', 'concerns')
    config.time_zone = 'UTC'

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = Figaro.env.available_locales.try(:split, ' ') || %w[en]
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true

    routes.default_url_options[:host] = Figaro.env.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = Figaro.env.email_from
        mail.display_name = Figaro.env.email_from_display_name
      end.to_s,
    }

    config.lograge.custom_options = lambda do |event|
      event.payload[:timestamp] = Time.zone.now.iso8601
      event.payload[:uuid] = SecureRandom.uuid
      event.payload[:pid] = Process.pid
      event.payload.except(:params, :headers)
    end

    # Refuse to run if migraitons are pending. Migrations should be run out
    # of band from launching the app
    config.active_record.migration_error = :page_load

    # Use a custom log formatter to get timestamp
    config.log_formatter = Upaya::UpayaLogFormatter.new

    require 'headers_filter'
    config.middleware.insert_before 0, HeadersFilter
    require 'utf8_sanitizer'
    config.middleware.use Utf8Sanitizer

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          next if source == Figaro.env.domain_name

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

    if Figaro.env.enable_rate_limiting == 'true'
      config.middleware.use Rack::Attack
    else
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end

    config.middleware.use(
      Rack::TwilioWebhookAuthentication,
      Figaro.env.twilio_auth_token,
      '/api/voice/otp',
    )
    config.middleware.use(
      Rack::TwilioWebhookAuthentication,
      Figaro.env.twilio_auth_token,
      '/api/twilio/voice',
    )
  end
end
