module TwoFactorAuthentication
  class PhoneDeletionForm
    include ActiveModel::Model
    include RememberDeviceConcern

    attr_reader :user, :configuration

    validates :user, multiple_mfa_options: true
    validates :configuration, allow_nil: true, owned_by_user: true

    def initialize(user, configuration)
      @user = user
      @configuration = configuration
    end

    def submit
      success = configuration.blank? || valid? && configuration_destroyed

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    def extra_analytics_attributes
      {
        configuration_present: configuration.present?,
        configuration_id: configuration&.id,
        configuration_owner: configuration&.user&.uuid,
        mfa_method_counts: MfaContext.new(user.reload).enabled_two_factor_configuration_counts_hash,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      }
    end

    def configuration_destroyed
      if configuration.destroy != false
        user.phone_configurations.reload
        revoke_remember_device(user)
        true
      else
        errors.add(
          :configuration,
          :not_destroyed,
          message: 'cannot delete phone',
          type: :two_factor,
        )
        false
      end
    end
  end
end
