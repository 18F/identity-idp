namespace :remote_settings do
  task :update, %i[name url] => [:environment] do |_task, args|
    RemoteSettingsService.update_setting(args[:name], args[:url])
    Kernel.puts 'Update successful'
  end

  task :view, [:name] => [:environment] do |_task, args|
    Kernel.puts RemoteSetting.find_by(name: args[:name])&.contents
  end

  task list: :environment do
    RemoteSetting.all.each do |rec|
      Kernel.puts "name=#{rec.name} url=#{rec.url}"
    end
  end

  task :delete, [:name] => [:environment] do |_task, args|
    RemoteSetting.where(name: args[:name]).delete_all
    Kernel.puts 'Delete successful'
  end
end

# rubocop:disable Metrics/LineLength
# example invocations:
# rake "remote_settings:update[agencies.yml,https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml]"
# rake "remote_settings:update[agencies.yml,https://login.gov/assets/idp/config/agencies.yml"
# rake "remote_settings:update[service_providers.yml,https://raw.githubusercontent.com/18F/identity-idp/master/config/service_providers.yml]"
# rubocop:enable Metrics/LineLength
