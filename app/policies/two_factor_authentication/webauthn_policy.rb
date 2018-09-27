module TwoFactorAuthentication
  # The WebauthnPolicy class is responsible for handling the user policy of webauthn
  class WebauthnPolicy
    def initialize(user, sp)
      @mfa_user = MfaContext.new(user)
      @sp = sp
    end

    def configured?
      webauthn_enabled? && mfa_user.webauthn_configurations.any?
    end

    def enabled?
      configured?
    end

    # :reek:UtilityFunction
    def available?
      webauthn_enabled?
    end

    # :reek:UtilityFunction
    def visible?
      webauthn_enabled?
    end

    private

    attr_reader :mfa_user, :sp

    def webauthn_enabled?
      sp.nil? && FeatureManagement.webauthn_enabled?
    end
  end
end
