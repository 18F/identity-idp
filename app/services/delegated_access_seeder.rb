# frozen_string_literal: true

# Update the delegated-access content from config/delegated_access.yml (all environments in
# rake db:seed): the agencies with their consent content, the service providers approved to
# act for people, and the agency applications with their API URLs.
#
# The file is keyed by Rails environment at the top level like config/service_providers.yml, with
# `agencies` (keyed by agency id, the shape of config/agencies.yml) and `service_providers`
# (keyed by issuer, the shape of config/service_providers.yml) under each. In deployed
# environments it comes from the identity-idp-config repository, linked into config/ by
# deploy/activate; locally bin/setup links the fixture config/delegated_access.localdev.yml in
# its place. An environment with no file, or no key for the current Rails environment, seeds
# nothing.
#
# Every entry may carry `restrict_to_deploy_env` (prod, staging, sandbox, or blank for everything
# except prod), applied by DeployEnvRestriction exactly as for service_providers.yml. Service
# providers are written through ServiceProviderSeeder#write_service_provider, so nested
# token_exchange_resource_servers and certificate lookup behave as they do for every other
# service provider.
class DelegatedAccessSeeder
  def initialize(
    rails_env: Rails.env,
    deploy_env: Identity::Hostdata.env,
    yaml_path: 'config/delegated_access.yml'
  )
    @rails_env = rails_env
    @deploy_env = deploy_env
    @yaml_path = yaml_path
  end

  def run
    data = load_yaml
    return if data.nil?

    seed_agencies(data.fetch('agencies', {}))
    seed_service_providers(data.fetch('service_providers', {}))
  end

  private

  attr_reader :rails_env, :deploy_env, :yaml_path

  # Nil when there is no file to read: the path is absent or a symlink to nothing (Pathname#exist?
  # follows the link). Otherwise the file is ERB first so hosts can come from the environment,
  # then YAML, then the section for the current Rails environment.
  def load_yaml
    file = Rails.root.join(yaml_path)
    return nil unless file.exist?

    content = YAML.safe_load(ERB.new(file.read).result, permitted_classes: [Date]) || {}
    content.fetch(rails_env, {})
  end

  # Agencies are upserted with every key passed through (name, abbreviation and the consent
  # content) except the deploy-environment restriction, which is not a column.
  def seed_agencies(agencies)
    agencies.each do |agency_id, config|
      next unless restriction.allows?(config)

      attributes = config.except('restrict_to_deploy_env')
      agency = Agency.find_by(id: agency_id)
      if agency
        agency.update!(attributes)
      else
        Agency.create!(attributes.merge(id: agency_id))
      end
    end
  end

  # ServiceProviderSeeder#write_service_provider applies the deploy-environment restriction
  # itself and strips the key before writing.
  def seed_service_providers(service_providers)
    seeder = ServiceProviderSeeder.new(rails_env: rails_env, deploy_env: deploy_env)
    service_providers.each do |issuer, config|
      seeder.write_service_provider(issuer: issuer, config: config)
    end
  end

  def restriction
    @restriction ||= DeployEnvRestriction.new(rails_env: rails_env, deploy_env: deploy_env)
  end
end
