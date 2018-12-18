module TwoFactorAuthentication
  class BackupCodePolicy
    def initialize(user)
      @user = user
    end

    def configured?
      @user.backup_code_configurations.unused.any?
    end

    def enabled?
      configured?
    end

    # :reek:UtilityFunction
    def visible?
      FeatureManagement.backup_codes_enabled?
    end

    # :reek:UtilityFunction
    def available?
      FeatureManagement.backup_codes_enabled?
    end

    private

    attr_reader :user
  end
end
