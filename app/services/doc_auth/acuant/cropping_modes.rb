module IdentityDocAuth
  module Acuant
    module CroppingModes
      # No cropping is performed (default).
      NONE = '0'.freeze
      # Automatically determine whether cropping is required. Not recommended.
      AUTOMATIC = '1'.freeze
      # Cropping is always performed.
      ALWAYS = '3'.freeze

      ALL = [
        NONE,
        AUTOMATIC,
        ALWAYS,
      ].freeze
    end
  end
end
