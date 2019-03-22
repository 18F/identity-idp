module TwoFactorAuthentication
  class PersonalKeyPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.encrypted_recovery_code_digest.present?
    end

    def enabled?
      configured?
    end

    # :reek:UtilityFunction
    def visible?
      !FeatureManagement.force_multiple_auth_methods?
    end

    private

    attr_reader :user
  end
end
