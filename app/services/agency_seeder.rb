# Update Agency from config/agencies.yml (all environments in rake db:seed)
class AgencySeeder
  def initialize(rails_env: Rails.env, deploy_env: LoginGov::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
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

  attr_reader :rails_env, :deploy_env

  def agencies
    file = remote_setting || Rails.root.join('config', 'agencies.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content).fetch(rails_env, {})
  end

  def remote_setting
    RemoteSetting.find_by(name: 'agencies.yml')&.contents
  end
end
