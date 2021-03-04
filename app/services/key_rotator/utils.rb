module KeyRotator
  class Utils
    def self.old_keys(config_name)
      JSON.parse(Identity::Hostdata.settings.send(config_name) || '[]')
    end
  end
end
