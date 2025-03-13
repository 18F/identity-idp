# frozen_string_literal: true

module TwoFactorAuthentication
  # Checks if a user has a personal key as a 2FA method
  # (legacy 2FA, independent of having one for a profile)
  class PersonalKeyPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.has_recovery_code?
    end

    def enabled?
      configured? && user.profiles.none?
    end

    private

    attr_reader :user
  end
end
