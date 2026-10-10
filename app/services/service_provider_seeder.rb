# frozen_string_literal: true

# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
#
# Delegated access adds two kinds of data to a service provider entry, both passed straight
# through to the record: the service provider fields (token_exchange_enabled_sp and the
# delegation_* content) and, for an agency application, delegation_application,
# delegation_scope_value, the consent content, allowed_delegation_service_providers and a nested
# token_exchange_resource_servers list (the application's API URLs), written by
# #write_resource_servers.
#
# Dependency: in production this YAML comes from the identity-idp-config repository, and in lower
# environments the same records are synced from the partner Dashboard (identity-dashboard) by
# ServiceProviderUpdater. The Dashboard does not have the delegated-access fields yet; until it
# does, `rake delegated_access:seed` loads them in non-production environments.
class ServiceProviderSeeder
  class ExtraServiceProviderError < StandardError; end

  def initialize(rails_env: Rails.env, deploy_env: Identity::Hostdata.env, yaml_path: 'config')
    @rails_env = rails_env
    @deploy_env = deploy_env
    @yaml_path = yaml_path
  end

  def run
    check_for_missing_sps

    service_providers.each do |issuer, config|
      write_service_provider(issuer: issuer, config: config)
    end
  end

  # Seed data appropriate only to per-branch review applications.
  # This method must not run in production.
  def run_review_app(dashboard_url:)
    return run if service_provider_data&.include?(dashboard_url)

    issuer = 'urn:gov:gsa:openidconnect.profiles:sp:sso:gsa:dashboard'
    config = {
      'friendly_name' => 'Dashboard',
      'agency' => 'GSA',
      'agency_id' => 2,
      'logo' => '18f.svg',
      'certs' => ['identity_dashboard_cert'],
      'return_to_sp_url' => dashboard_url,
      'redirect_uris' => [
        "#{dashboard_url}/auth/logindotgov/callback",
        dashboard_url,
      ],
      'push_notification_url' => "#{dashboard_url}/api/security_events",
    }

    write_service_provider(issuer: issuer, config: config)
  end

  # Upserts one service provider entry (one key of service_providers.yml and its nested API URLs).
  # Public so DelegatedAccessSeeder can load its fixtures through the same code path.
  def write_service_provider(issuer:, config:)
    return unless write_service_provider?(config)

    cert_pems = Array(config['certs']).map do |cert|
      cert_path = Rails.root.join('certs', 'sp', "#{cert}.crt")
      cert_path.read if cert_path.exist?
    end.compact

    service_provider = ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
      sp.update(
        approved: true,
        active: true,
        native: true,
        friendly_name: config['friendly_name'],
      )
    end
    service_provider.update!(
      config.except(
        'agency',
        'certs',
        'restrict_to_deploy_env',
        'protocol',
        'native',
        'token_exchange_resource_servers',
      ).merge(certs: cert_pems),
    )

    write_resource_servers(service_provider, config['token_exchange_resource_servers'])
  end

  private

  attr_reader :rails_env, :deploy_env

  def service_providers
    file = service_provider_data
    return [] unless file

    file.gsub!('%{env}', deploy_env) if deploy_env
    YAML.safe_load(file, permitted_classes: [Date]).fetch(rails_env)
  rescue Psych::SyntaxError => syntax_error
    Rails.logger.error { "Syntax error loading service_providers.yml: #{syntax_error.message}" }
    raise syntax_error
  rescue KeyError => key_error
    Rails.logger.error { "Missing env in service_providers.yml?: #{key_error.message}" }
    raise key_error
  end

  def service_provider_data
    file = Rails.root.join(@yaml_path, 'service_providers.yml')
    file.read if file.exist?
  end

  def write_service_provider?(config)
    return true if rails_env != 'production'

    restrict_env = config['restrict_to_deploy_env']
    in_prod = deploy_env == 'prod'
    in_sandbox = !%w[prod staging].include?(deploy_env)
    in_staging = deploy_env == 'staging'

    return true if restrict_env == 'prod' && in_prod
    return true if restrict_env == 'staging' && in_staging
    return true if restrict_env == 'sandbox' && in_sandbox
    return true if restrict_env.blank? && !in_prod

    false
  end

  def check_for_missing_sps
    return unless %w[prod staging].include? deploy_env

    sps_in_db = ServiceProvider.pluck(:issuer)
    sps_in_yaml = service_providers.keys
    extra_sps = sps_in_db - sps_in_yaml

    return if extra_sps.empty?

    extra_sp_error = ExtraServiceProviderError.new(
      "Extra service providers found in DB: #{extra_sps.join(', ')}",
    )

    if IdentityConfig.store.team_ursula_email.present?
      ReportMailer.warn_error(
        email: IdentityConfig.store.team_ursula_email,
        error: extra_sp_error,
      ).deliver_now
    end
  end

  # The API URLs of an application, nested under its entry as token_exchange_resource_servers and
  # upserted by identifier so re-running the seeder is idempotent. Each entry carries the columns
  # of TokenExchangeResourceServer; `certs` are resolved like service provider certs (a name under
  # certs/sp, or an inline PEM), and `attempts_service_provider` names the record whose Attempts
  # API credentials receive fraud-signal events for the URL.
  def write_resource_servers(service_provider, resource_server_configs)
    return if resource_server_configs.nil?

    Array(resource_server_configs).each do |rs_config|
      rs_config = rs_config.stringify_keys
      resource_server = service_provider.token_exchange_resource_servers
        .find_or_initialize_by(identifier: rs_config.fetch('identifier'))
      resource_server.update!(
        rs_config
          .except('identifier', 'certs', 'attempts_service_provider')
          .merge(
            certs: load_cert_pems(rs_config['certs']),
            attempts_service_provider:
              lookup_service_provider(rs_config['attempts_service_provider']),
          ),
      )
      resource_server.warn_if_unbillable
    end
  end

  def lookup_service_provider(issuer)
    return nil if issuer.blank?

    ServiceProvider.find_by(issuer: issuer)
  end

  # A certificate given by name is read from certs/sp/<name>.crt; an inline PEM is kept as is. A
  # missing file is skipped so a fixture may name a certificate each developer generates locally.
  def load_cert_pems(cert_names)
    Array(cert_names).map do |cert|
      next cert if cert.to_s.include?('-----BEGIN CERTIFICATE-----')

      cert_path = Rails.root.join('certs', 'sp', "#{cert}.crt")
      cert_path.read if cert_path.exist?
    end.compact
  end
end
