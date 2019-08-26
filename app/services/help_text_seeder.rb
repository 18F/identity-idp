# Update Help Texts from config/help_texts.yml (all environments in rake db:seed)
class HelpTextSeeder
  def initialize(rails_env: Rails.env, deploy_env: LoginGov::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  def run
    help_texts.each do |sp_issuer, config|
      service_provider = ServiceProvider.find_by(issuer: sp_issuer)
      help_text = service_provider.help_text
      if help_text
        help_text.update!(config)
      else
        HelpText.create!(config.merge(id: help_text_id))
      end
    end
  end

  private

  attr_reader :rails_env, :deploy_env

  def help_texts
    file = remote_setting || Rails.root.join('config', 'help_texts.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content).fetch(rails_env, {})
  end

  def remote_setting
    RemoteSetting.find_by(name: 'help_texts.yml')&.contents
  end
end
