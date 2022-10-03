class KeyPairGeneratorComponent < BaseComponent
  attr_reader :location

  def initialize(location:)
    @location = location
  end

  def render?
    AbTests::KEY_PAIR_GENERATION.bucket(SecureRandom.uuid) == :key_pair_group
  end
end
