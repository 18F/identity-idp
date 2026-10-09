# frozen_string_literal: true

# Loads the delegated-access fixtures (agencies with consent content, a service provider approved
# for delegation, and agency applications with their API URLs) from a YAML file into the
# database, for local development, review apps and personal sandboxes.
#
# This exists because the records a sandbox needs cannot come through the usual channels yet: the
# shared identity-idp-config repository cannot carry fields that `main` does not know, and the
# partner Dashboard does not have the delegated-access fields. The seeder writes through the same
# code path as the production seeder (ServiceProviderSeeder#write_service_provider), so the data
# shape is identical; only the source file differs.
#
# It refuses to run in prod and staging.
class DelegatedAccessSeeder
  class RefusedEnvironment < StandardError; end

  REFUSED_DEPLOY_ENVIRONMENTS = %w[prod staging].freeze
  DEFAULT_YAML_PATH = 'config/delegated_access.localdev.yml'

  def initialize(yaml_path: DEFAULT_YAML_PATH, deploy_env: Identity::Hostdata.env)
    @yaml_path = yaml_path
    @deploy_env = deploy_env
  end

  def run
    if REFUSED_DEPLOY_ENVIRONMENTS.include?(deploy_env.to_s)
      raise RefusedEnvironment, "delegated access fixtures are not loaded in #{deploy_env}"
    end

    data = load_yaml
    seed_agencies(data.fetch('agencies', {}))
    seed_service_providers(data.fetch('service_providers', {}))
  end

  private

  attr_reader :yaml_path, :deploy_env

  # The file is ERB first so hosts can come from the environment, then YAML.
  def load_yaml
    file = Rails.root.join(yaml_path).read
    YAML.safe_load(ERB.new(file).result, permitted_classes: [Date]) || {}
  end

  # Agencies are keyed by id, as in config/agencies.yml, and upserted with every key passed
  # through (name, abbreviation and the delegated-access consent content).
  def seed_agencies(agencies)
    agencies.each do |agency_id, config|
      agency = Agency.find_by(id: agency_id)
      if agency
        agency.update!(config)
      else
        Agency.create!(config.merge(id: agency_id))
      end
    end
  end

  # Service providers (the delegating one and the agency applications) are keyed by issuer, as in
  # config/service_providers.yml, and written by the production seeder's own upsert so nested
  # token_exchange_resource_servers and certificate lookup behave exactly as they do there.
  def seed_service_providers(service_providers)
    seeder = ServiceProviderSeeder.new(deploy_env: deploy_env)
    service_providers.each do |issuer, config|
      seeder.write_service_provider(issuer: issuer, config: config)
    end
  end
end
