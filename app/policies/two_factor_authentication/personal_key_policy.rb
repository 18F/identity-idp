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

    def visible?
      enabled?
    end

    private

    attr_reader :user
  end
end
