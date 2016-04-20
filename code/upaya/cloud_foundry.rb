module CloudFoundry
  def self.raw_vcap_data
    ENV['VCAP_APPLICATION']
  end

  def self.vcap_data
    if is_environment?
      JSON.parse(raw_vcap_data)
    else
      nil
    end
  end

  # returns `true` if this app is running in Cloud Foundry
  def self.is_environment?
    !!raw_vcap_data
  end

  def self.instance_index
    if is_environment?
      vcap_data['instance_index']
    else
      nil
    end
  end
end
