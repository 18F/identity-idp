require_relative 'boot'

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'identity/logging/railtie'

require_relative '../lib/asset_sources'
require_relative '../lib/identity_config'
require_relative '../lib/load_disposable_domain'
require_relative '../lib/fingerprinter'
require_relative '../lib/identity_job_log_subscriber'
require_relative '../lib/email_delivery_observer'
require_relative '../lib/good_job_connection_pool_size'
require_relative '../lib/identity_cors'
require_relative '../lib/version_headers'
require_relative '../lib/idp/constants'

Bundler.require(*Rails.groups)

require_relative '../lib/mailer_sensitive_information_checker'

APP_NAME = 'Login.gov'.freeze

module Identity
  class Application < Rails::Application
    if (log_level = ENV['LOGIN_TASK_LOG_LEVEL'])
      Identity::Hostdata.logger.level = log_level
    end

    configuration = Identity::Hostdata::ConfigReader.new(
      app_root: Rails.root,
      logger: Identity::Hostdata.logger,
    ).read_configuration(
      Rails.env, write_copy_to: Rails.root.join('tmp', 'application.yml')
    )
    IdentityConfig.build_store(configuration)

    AssetSources.manifest_path = Rails.public_path.join('packs', 'manifest.json')
    AssetSources.cache_manifest = Rails.env.production? || Rails.env.test?

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

    config.load_defaults '7.0'
    config.active_record.belongs_to_required_by_default = false
    config.active_record.legacy_connection_handling = false
    config.active_job.queue_adapter = :good_job

    FileUtils.mkdir_p(Rails.root.join('log'))
    config.active_job.logger = ActiveSupport::Logger.new(Rails.root.join('log', 'workers.log'))
    config.active_job.logger.formatter = config.log_formatter

    config.good_job.execution_mode = :external
    config.good_job.poll_interval = 5
    config.good_job.enable_cron = true
    config.good_job.max_threads = IdentityConfig.store.good_job_max_threads
    config.good_job.queues = IdentityConfig.store.good_job_queues
    config.good_job.preserve_job_records = false
    config.good_job.enable_listen_notify = false
    config.good_job.queue_select_limit = IdentityConfig.store.good_job_queue_select_limit
    # see config/initializers/job_configurations.rb for cron schedule

    includes_star_queue = config.good_job.queues.split(';').any? do |name_threads|
      name, _threads = name_threads.split(':', 2)
      name == '*'
    end
    raise 'good_job.queues does not contain *, but it should' if !includes_star_queue

    GoodJob.active_record_parent_class = 'WorkerJobApplicationRecord'
    GoodJob.retry_on_unhandled_error = false
    GoodJob.on_thread_error = ->(exception) { NewRelic::Agent.notice_error(exception) }

    config.time_zone = 'UTC'

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = Idp::Constants::AVAILABLE_LOCALES
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true

    config.action_view.frozen_string_literal = true

    routes.default_url_options[:host] = IdentityConfig.store.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = IdentityConfig.store.email_from
        mail.display_name = IdentityConfig.store.email_from_display_name
      end.to_s,
    }
    config.action_mailer.observers = %w[EmailDeliveryObserver]

    config.middleware.delete Rack::ETag

    require 'headers_filter'
    config.middleware.insert_before 0, HeadersFilter
    require 'utf8_sanitizer'
    config.middleware.use Utf8Sanitizer
    require 'secure_cookies'
    config.middleware.insert_after ActionDispatch::Static, SecureCookies
    config.middleware.use VersionHeaders if IdentityConfig.store.version_headers_enabled

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          IdentityCors.allowed_redirect_uri?(source)
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
        origins IdentityCors.allowed_origins_static_sites
        resource '/api/analytics-events', headers: :any, methods: [:get]
        resource '/api/country-support', headers: :any, methods: [:get]
        if IdentityConfig.store.in_person_public_address_search_enabled
          resource '/api/usps_locations', headers: :any, methods: %i[post options]
        end
      end
    end

    if !IdentityConfig.store.enable_rate_limiting
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end

    config.view_component.show_previews = IdentityConfig.store.component_previews_enabled
    if IdentityConfig.store.component_previews_enabled
      require 'lookbook'

      config.view_component.preview_controller = 'ComponentPreviewController'
      config.view_component.preview_paths = [Rails.root.join('spec', 'components', 'previews')]
      config.view_component.default_preview_layout = 'component_preview'
      config.lookbook.auto_refresh = false
      config.lookbook.project_name = "#{APP_NAME} Component Previews"
      config.lookbook.ui_theme = 'blue'
    end
  end
end
