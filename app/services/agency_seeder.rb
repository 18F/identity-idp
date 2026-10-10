# frozen_string_literal: true

# Update Agency from config/agencies.yml (all environments in rake db:seed)
#
# Every key of an agency entry is passed through to the record, including the delegated-access
# consent content (delegation_description, delegation_learn_more_url and the content version
# pair). Dependency: the partner Dashboard does not carry these agency fields; the agencies that
# have them are seeded from config/delegated_access.yml by DelegatedAccessSeeder.
class AgencySeeder
  def initialize(
    rails_env: Rails.env,
    deploy_env: Identity::Hostdata.env,
    yaml_path: 'config'
  )
    @rails_env = rails_env
    @deploy_env = deploy_env
    @yaml_path = yaml_path
  end

  def run
    agencies.each do |agency_id, config|
      agency = Agency.find_by(id: agency_id)
      if agency
        agency.update!(config)
      else
        Agency.create!(config.merge(id: agency_id))
      end
    end
  end

  private

  attr_reader :rails_env, :deploy_env, :yaml_path

  def agencies
    file = Rails.root.join(yaml_path, 'agencies.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content).fetch(rails_env, {})
  end
end
