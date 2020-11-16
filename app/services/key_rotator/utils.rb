module KeyRotator
  class Utils
    def self.old_keys(config_name)
      JSON.parse(AppConfig.env.send(config_name) || '[]')
    end
  end
end
