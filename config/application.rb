require_relative 'boot'

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'
require 'identity/logging/railtie'

require_relative '../lib/identity_config'
require_relative '../lib/fingerprinter'
require_relative '../lib/identity_job_log_subscriber'

Bundler.require(*Rails.groups)

APP_NAME = 'Login.gov'.freeze

module Upaya
  class Application < Rails::Application
    configuration = Identity::Hostdata::ConfigReader.new(app_root: Rails.root).read_configuration(
      Rails.env, write_copy_to: Rails.root.join('tmp', 'application.yml')
    )
    IdentityConfig.build_store(configuration)

    console do
      if ENV['ALLOW_CONSOLE_DB_WRITE_ACCESS'] != 'true' &&
         IdentityConfig.store.database_readonly_username.present? &&
         IdentityConfig.store.database_readonly_password.present?
        warn <<-EOS.squish
          WARNING: Loading database a configuration with the readonly database user.
          If you wish to make changes to records in the database set
          ALLOW_CONSOLE_DB_WRITE_ACCESS to "true" in the environment
        EOS

        ActiveRecord::Base.establish_connection :read_replica
      end
    end

    config.load_defaults '6.1'
    config.active_record.belongs_to_required_by_default = false
    config.active_record.legacy_connection_handling = false
    config.assets.unknown_asset_fallback = true
    config.active_job.queue_adapter = :good_job

    FileUtils.mkdir_p(Rails.root.join('log'))
    config.active_job.logger = ActiveSupport::Logger.new(Rails.root.join('log', 'workers.log'))
    config.active_job.logger.formatter = config.log_formatter

    config.good_job.execution_mode = :external
    config.good_job.poll_interval = 5
    config.good_job.enable_cron = true
    config.good_job.max_threads = IdentityConfig.store.good_job_max_threads
    config.good_job.queues = IdentityConfig.store.good_job_queues
    # see config/initializers/job_configurations.rb for cron schedule

    GoodJob.active_record_parent_class = 'WorkerJobApplicationRecord'
    GoodJob.retry_on_unhandled_error = false
    GoodJob.on_thread_error = ->(exception) { NewRelic::Agent.notice_error(exception) }

    config.time_zone = 'UTC'

    # Generate CSRF tokens that are encoded in URL-safe Base64.
    #
    # This change is not backwards compatible with earlier Rails versions.
    # It's best enabled when your entire app is migrated and stable on 6.1.
    Rails.application.config.action_controller.urlsafe_csrf_tokens = false

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = %w[en es fr]
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true

    routes.default_url_options[:host] = IdentityConfig.store.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = IdentityConfig.store.email_from
        mail.display_name = IdentityConfig.store.email_from_display_name
      end.to_s,
    }

    require 'headers_filter'
    config.middleware.insert_before 0, HeadersFilter
    require 'utf8_sanitizer'
    config.middleware.use Utf8Sanitizer

    # rubocop:disable Metrics/BlockLength
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          next if source == IdentityConfig.store.domain_name

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

      allow do
        allowed_origins = [
          'https://www.login.gov',
          'https://login.gov',
          %r{^https://federalist-[0-9a-f-]+\.app\.cloud\.gov$},
        ]

        if Rails.env.development? || Rails.env.test?
          allowed_origins << %r{https?://localhost(:\d+)?$}
          allowed_origins << %r{https?://127\.0\.0\.1(:\d+)?$}
        end

        origins allowed_origins
        resource '/api/country-support', headers: :any, methods: [:get]
      end
    end
    # rubocop:enable Metrics/BlockLength

    if IdentityConfig.store.enable_rate_limiting
      config.middleware.use Rack::Attack
    else
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end
  end
end
