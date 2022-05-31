module TwoFactorAuthentication
  # The WebauthnPolicy class is responsible for handling the user policy of webauthn
  class WebauthnPolicy
    def initialize(user)
      @mfa_user = MfaContext.new(user)
    end

    def configured?
      mfa_user.webauthn_configurations.any?
    end

    def enabled?
      configured?
    end

    def platform_configured?
      mfa_user.webauthn_platform_configurations.any?
    end

    def platform_enabled?
      platform_configured?
    end

    def roaming_configured?
      mfa_user.webauthn_roaming_configurations.any?
    end

    def roaming_enabled?
      roaming_configured?
    end

    def visible?
      true
    end

    private

    attr_reader :mfa_user
  end
end
