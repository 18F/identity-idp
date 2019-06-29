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

    def available?
      true
    end

    def visible?
      true
    end

    def second_phone?
      mfa_user.phone_configurations.any?
    end

    private

    attr_reader :mfa_user
  end
end
