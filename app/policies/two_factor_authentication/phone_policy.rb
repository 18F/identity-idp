# frozen_string_literal: true

module TwoFactorAuthentication
  class PhonePolicy
    def initialize(user)
      @mfa_user = MfaContext.new(user)
    end

    def configured?
      mfa_user.phone_configurations.any?
    end

    def enabled?
      mfa_user.phone_configurations.any?(&:mfa_enabled?)
    end

    def visible?
      true
    end

    private

    attr_reader :mfa_user
  end
end
