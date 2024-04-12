# frozen_string_literal: true

# Update Agency from config/agencies.yml (all environments in rake db:seed)
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
