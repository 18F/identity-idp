module TwoFactorAuthentication
  # The WebauthnPolicy class is responsible for handling the user policy of webauthn
  class WebauthnPolicy
    def initialize(user)
      @mfa_user = MfaContext.new(user)
    end

    def configured?
      FeatureManagement.webauthn_enabled? && mfa_user.webauthn_configurations.any?
    end

    def enabled?
      configured?
    end

    # :reek:UtilityFunction
    def available?
      FeatureManagement.webauthn_enabled?
    end

    # :reek:UtilityFunction
    def visible?
      FeatureManagement.webauthn_enabled?
    end

    private

    attr_reader :mfa_user
  end
end
