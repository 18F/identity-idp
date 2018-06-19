class RemoteSettingsService
  def self.load_yml_erb(location)
    result = ERB.new(load(location)).result
    begin
      YAML.safe_load(result.to_s)
    rescue StandardError
      raise "Error parsing yml file: #{location}"
    end
    result
  end

  def self.load(location)
    raise "Location must begin with 'https://': #{location}" unless remote?(location)
    response = HTTParty.get(
      location, headers:
      { 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1' }
    )
    raise "Error retrieving: #{location}" unless response.code == 200
    response.body
  end

  def self.update_setting(name, url)
    remote_setting = RemoteSetting.where(name: name).first_or_initialize
    remote_setting.url = url
    raise "url not whitelisted: #{url}" unless remote_setting.valid?
    remote_setting.contents = RemoteSettingsService.load(remote_setting.url)
    remote_setting.save
  end

  def self.remote?(location)
    location.to_s.starts_with?('https://')
  end
end
