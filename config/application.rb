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

APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    configuration = Identity::Hostdata::ConfigReader.new(app_root: Rails.root).read_configuration(
      Rails.env, write_copy_to: Rails.root.join('tmp', 'application.yml')
    )
    IdentityConfig.build_store(configuration)

    yaml_config = Identity::Hostdata::ConfigReader.new(app_root: Rails.root).read_configuration(
      Rails.env, write_copy_to: Rails.root.join('tmp', 'application.yml')
    )
    ssm_config = Identity::Hostdata::SsmReader()
    env_config = ENV.take('my_keys')

    IdentityConfig.new([:yaml, :ssm, :env], {yaml: yaml_config, ssm: ssm_config, env: env_config})
    keys = [:yaml, :ssm, :env]
    map_of_configs = {yaml: yaml_config, ssm: ssm_config, env: env_config}
    keys.reduce do |config, key|
      config.merge(map_of_configs[key])
      validate!(config)
      config
    end    

    Identity::Hostdata.setup do |config|
      # application.yml
      #   load the default frmo source control
      #   load the one from S3
      #   parse em into a DSL

      def merge_ymls(**args)
        
      end

      combined = (
        YAML.load(Rails.root.join('default.yml')),
        { s3_config: '' }
        if in_datacenter?
          config.app_secrets_s3('/%<env>/idp/application.yml')
        else
          Rails.root.join('override.yml')
        end,
        ENV,
      ).define(ssm_prefix: '/idp/foo/bar') do |config|
         # set up ***all*** the keys 
        add(:aal_authn_context_enabled, type: :boolean)
        ## ssm happens inside here
      end

      define_keys do |config|
        # set up ***all*** the keys 
        add(:aal_authn_context_enabled, type: :boolean

        add(:aamva_cert_enabled, type: :boolean, :error_on_default_in_prod)
        add(:aamva_private_key, type: :string)
        add(:aamva_public_key, type: :string)
        add(:aamva_sp_banlist_issuers, type: :json)
        add(:aamva_verification_request_timeout, type: :integer)
      end.load_from(
        EnvSource(ENV), # most important
        config.ssm_source, # second most important
        config.yaml_config('/env/ymal'),
        config.local_yaml_source('application.yml') # least/default
      )

      class SecretSource
        def source_name
        end

        def has_key?()
        end

        def get
        end
      end
    
      # use cases we want to guard again
      ### I put a bad value in application.yml, but it's masked by a good value in ENV
      ### Optionally error on default value in prod (unsafe default)
      ### validations on the type?
      #### ex: JSON but it's not JSON
      #### make sure they're not nil, flag to ignore that
      ## collect all the errors, don't blow up on the first one

      def load_from(*sources)
        @errors = Hash.new { |k, v| k[v] = [] }
        @errors[:foo] << "some thing is wrongggg"


        config_defs.each do |key, type, etc|
          sources.each do |source|
            # check for error_on_default_in_prod
            if source.has_key?(key)
              set_value(source.load_key(key))
              save_source
              break
            end
          end
          errors << error
          # oh no the key is not defined anywhere, time to load an error
        end
      end

      # download arbirary secrets & expose them as properties
      config.define do |config|
        # set up all the artifacts
        store.add_artifact(:saml_2020_key, '/%<env>s/saml2020.key.enc')
      end
    end

    Identity::Hostdata.store.aal_authn_context_enabled # its a boolean
    Identity::Hostdata.store.saml_2020_key # its a blarb

    # example DSL

    Identity::Hostdata.store.setup do |store|
      store.define(:aamva_cert_enabled, type: :boolean, :error_on_default_in_prod)
      store.define(:aamva_private_key, type: :string)
      store.define(:saml_2020_key, artifact_path: '/%<env>s/saml2020.key.enc')

      store.load_from(
        env: Rails.env,
        sources: [ 
          store.local_yaml_source(Rails.root.join('config/application.yml.default')),
          store.s3_yaml_source('/<env>/v1/idp/application.yml')), # no-op if nil
          store.ssm_source, # no-op in local
          store.s3_bucket1, # no-op in local
          store.environment_source(ENV), # last one wins
        ]
      )
    end

    Identity::Hostdata.store.aal_authn_context_enabled # its a boolean

    # end example


    config.load_defaults '6.1'
    config.active_record.belongs_to_required_by_default = false
    config.assets.unknown_asset_fallback = true

    if IdentityConfig.store.ruby_workers_enabled
      config.active_job.queue_adapter = :delayed_job
    else
      config.active_job.queue_adapter = :inline
    end

    FileUtils.mkdir_p(Rails.root.join('log'))
    config.active_job.logger = ActiveSupport::Logger.new(Rails.root.join('log', 'workers.log'))
    config.active_job.logger.formatter = config.log_formatter

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
    end

    if IdentityConfig.store.enable_rate_limiting
      config.middleware.use Rack::Attack
    else
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end
  end
end
