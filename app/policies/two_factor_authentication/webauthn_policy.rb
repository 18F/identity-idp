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

    # :reek:UtilityFunction
    def available?
      true
    end

    # :reek:UtilityFunction
    def visible?
      true
    end

    private

    attr_reader :mfa_user
  end
end
