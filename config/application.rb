# frozen_string_literal: true

require_relative 'boot'

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'identity/logging/railtie'

require_relative '../lib/asset_sources'
require_relative '../lib/identity_config'
require_relative '../lib/feature_management'
require_relative '../lib/fingerprinter'
require_relative '../lib/identity_job_log_subscriber'
require_relative '../lib/email_delivery_observer'
require_relative '../lib/good_job_connection_pool_size'
require_relative '../lib/identity_cors'
require_relative '../lib/version_headers'
require_relative '../lib/idp/constants'

Bundler.require(*Rails.groups)

require_relative '../lib/mailer_sensitive_information_checker'

APP_NAME = 'Login.gov'

module Identity
  class Application < Rails::Application
    if (log_level = ENV['LOGIN_TASK_LOG_LEVEL'])
      Identity::Hostdata.logger.level = log_level
    end

    Identity::Hostdata.load_config!(
      app_root: Rails.root,
      rails_env: Rails.env,
      write_copy_to: nil,
      &IdentityConfig::BUILDER
    )

    config.asset_sources = AssetSources.new(
      manifest_path: Rails.public_path.join('packs', 'manifest.json'),
      cache_manifest: Rails.env.production? || Rails.env.test?,
      i18n_locales: Identity::Hostdata.config.available_locales,
    )

    console do
      if ENV['ALLOW_CONSOLE_DB_WRITE_ACCESS'] != 'true' &&
         Identity::Hostdata.config.database_readonly_username.present? &&
         Identity::Hostdata.config.database_readonly_password.present?
        warn <<-EOS.squish
          WARNING: Loading database a configuration with the readonly database user.
          If you wish to make changes to records in the database set
          ALLOW_CONSOLE_DB_WRITE_ACCESS to "true" in the environment
        EOS

        ActiveRecord::Base.establish_connection :read_replica
      end
    end

    config.load_defaults '7.2'
    config.active_record.belongs_to_required_by_default = false
    config.active_job.queue_adapter = :good_job

    FileUtils.mkdir_p(Rails.root.join('log'))
    config.active_job.logger = if FeatureManagement.log_to_stdout?
                                 ActiveSupport::Logger.new(STDOUT)
                               else
                                 ActiveSupport::Logger.new(
                                   Rails.root.join('log', Idp::Constants::WORKER_LOG_FILENAME),
                                 )
                               end
    config.active_job.logger.formatter = config.log_formatter

    config.logger = if FeatureManagement.log_to_stdout?
                      ActiveSupport::Logger.new(STDOUT)
                    else
                      ActiveSupport::Logger.new(
                        Rails.root.join('log', "#{Rails.env}.log"),
                      )
                    end

    config.kms_logger = if FeatureManagement.log_to_stdout?
                          ActiveSupport::Logger.new(STDOUT)
                        else
                          ActiveSupport::Logger.new(
                            Rails.root.join('log', Idp::Constants::KMS_LOG_FILENAME),
                          )
                        end

    config.good_job.execution_mode = :external
    config.good_job.poll_interval = 5
    config.good_job.enable_cron = true
    config.good_job.max_threads = Identity::Hostdata.config.good_job_max_threads
    config.good_job.queues = Identity::Hostdata.config.good_job_queues
    config.good_job.preserve_job_records = false
    config.good_job.enable_listen_notify = false
    config.good_job.queue_select_limit = Identity::Hostdata.config.good_job_queue_select_limit
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

    require 'i18n_flat_yml_backend'
    config.i18n.backend = I18nFlatYmlBackend.new
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml,rb}')]
    config.i18n.available_locales = Identity::Hostdata.config.available_locales
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true

    config.action_view.frozen_string_literal = true

    routes.default_url_options[:host] = Identity::Hostdata.config.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = Identity::Hostdata.config.email_from
        mail.display_name = Identity::Hostdata.config.email_from_display_name
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
    config.middleware.use VersionHeaders if Identity::Hostdata.config.version_headers_enabled

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
        resource '/api/country-support', headers: :any, methods: [:get]
        resource '/api/usps_locations', headers: :any, methods: %i[post options]
      end
    end

    if !Identity::Hostdata.config.enable_rate_limiting
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end

    config.view_component.show_previews = Identity::Hostdata.config.component_previews_enabled
    if Identity::Hostdata.config.component_previews_enabled
      require 'lookbook'

      config.view_component.preview_controller = 'ComponentPreviewController'
      config.view_component.preview_paths = [Rails.root.join('spec', 'components', 'previews')]
      config.view_component.default_preview_layout = 'component_preview'
      config.lookbook.auto_refresh = false
      config.lookbook.project_name = "#{APP_NAME} Component Previews"
      config.lookbook.ui_theme = 'blue'
      if Identity::Hostdata.config.component_previews_embed_frame_ancestors.present?
        # so we can embed a lookbook component into the dev docs
        config.lookbook.preview_embeds.policy = 'ALLOWALL'
        # lookbook strips out CSP, this brings it back so we aren't so permissive
        require 'component_preview_csp'
        config.middleware.insert_after ActionDispatch::Static, ComponentPreviewCsp
      end
    end
  end
end
