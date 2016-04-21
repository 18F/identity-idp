require_relative 'cloud_foundry'

module ServerEnv
  def self.instance_index
    CloudFoundry.instance_index || 0
  end
end
