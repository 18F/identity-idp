module TwoFactorAuthentication
  class PhoneDeletionForm
    attr_reader :user, :configuration

    def initialize(user, configuration)
      @user = user
      @configuration = configuration
    end

    def submit
      success = configuration_absent? || multiple_factors_enabled? && configuration_destroyed

      FormResponse.new(success: success, errors: {}, extra: {})
    end

    private

    def configuration_absent?
      configuration.blank?
    end

    def multiple_factors_enabled?
      MfaPolicy.new(user).multiple_factors_enabled?
    end

    def configuration_destroyed
      configuration.destroy != false
    end
  end
end
