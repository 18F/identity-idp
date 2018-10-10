module TwoFactorAuthentication
  class PhoneDeletionForm
    include ActiveModel::Model

    attr_reader :user, :configuration

    def initialize(user, configuration)
      @user = user
      @configuration = configuration
    end

    def submit
      success = configuration_absent? ||
                configuration_owned_by_user? && multiple_factors_enabled? && configuration_destroyed

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        configuration_present: configuration.present?,
        configuration_id: configuration&.id,
        configuration_owner: configuration&.user&.uuid,
      }
    end

    def configuration_absent?
      configuration.blank?
    end

    def multiple_factors_enabled?
      return true if MfaPolicy.new(user).multiple_factors_enabled?
      errors.add(:configuration, :singular, message: 'cannot be the last MFA configuration')
      false
    end

    def configuration_destroyed
      return true if configuration.destroy != false
      errors.add(:configuration, :not_destroyed, message: 'cannot delete phone')
      false
    end

    def configuration_owned_by_user?
      return true if configuration.user_id == user.id
      errors.add(:configuration, :owner, message: "cannot delete someone else's phone")
      false
    end
  end
end
