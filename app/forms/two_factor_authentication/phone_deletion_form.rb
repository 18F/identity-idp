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
        configuration_present: configuration.present?,
        configuration_id: configuration&.id,
        configuration_owner: configuration&.user&.uuid,
        mfa_method_counts: MfaContext.new(user.reload).enabled_two_factor_configuration_counts_hash,
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
      if configuration.destroy != false
        user.phone_configurations.reload
        update_remember_device_revoked_at
        true
      else
        errors.add(:configuration, :not_destroyed, message: 'cannot delete phone')
        false
      end
    end

    # Just in case the controller drops the restriction on current_user
    def configuration_owned_by_user?
      return true if configuration.user_id == user.id
      errors.add(:configuration, :owner, message: "cannot delete someone else's phone")
      false
    end

    def update_remember_device_revoked_at
      attributes = { remember_device_revoked_at: Time.zone.now }
      UpdateUser.new(user: user, attributes: attributes).call
    end
  end
end
