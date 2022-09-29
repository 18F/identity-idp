# frozen_string_literal: true

class KeyPairGeneratorComponent < BaseComponent
  attr_reader :location

  def initialize(location:)
    @location = location
  end
end
