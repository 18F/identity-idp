require File.expand_path('../boot', __FILE__)
require 'rails/all'

Bundler.require(*Rails.groups)

APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    config.active_job.queue_adapter = :sidekiq
    config.autoload_paths << Rails.root.join('app', 'mailers', 'concerns')
    config.time_zone = 'UTC'

    config.browserify_rails.force = true
    config.browserify_rails.commandline_options = '-t [ babelify --presets [ es2015 ] ]'
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = Figaro.env.available_locales.try(:split, ' ') || %w[en]
    config.i18n.default_locale = :en

    routes.default_url_options[:host] = Figaro.env.domain_name

    if Rails.env.test?
      config.browserify_rails.commandline_options += ' -p [ proxyquireify/plugin ]'
      # Make sure Browserify is triggered when asked to serve javascript spec files
      config.browserify_rails.paths << lambda do |path|
        path.start_with?(Rails.root.join('spec', 'javascripts').to_s)
      end
    end

    config.lograge.custom_options = lambda do |event|
      event.payload[:timestamp] = event.time
      event.payload[:uuid] = SecureRandom.uuid
      event.payload[:pid] = Process.pid
      event.payload.except(:params, :headers)
    end

    require 'headers_filter'
    config.middleware.insert_before 0, HeadersFilter

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          next if source == Figaro.env.domain_name

          ServiceProvider.pluck(:redirect_uris).flatten.compact.find do |uri|
            match = URI::DEFAULT_PARSER.regexp[:ABS_URI].match(uri)
            parsed_uri = "#{match[1]}://#{match[4]}"
            parsed_uri += ":#{match[5]}" if match[5].present?
            source == parsed_uri
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
  end
end
