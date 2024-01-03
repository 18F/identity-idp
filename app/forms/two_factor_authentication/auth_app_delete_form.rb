module TwoFactorAuthentication
  class AuthAppDeleteForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    attr_reader :user, :configuration_id

    validate :validate_configuration_exists
    validate :validate_has_multiple_mfa

    def initialize(user:, configuration_id:)
      @user = user
      @configuration_id = configuration_id
    end

    def submit
      success = valid?

      configuration.destroy if success

      FormResponse.new(
        success:,
        errors:,
        extra: extra_analytics_attributes,
        serialize_error_details_only: true,
      )
    end

    def configuration
      @configuration ||= user.auth_app_configurations.find_by(id: configuration_id)
    end

    private

    def validate_configuration_exists
      return if configuration.present?
      errors.add(
        :configuration_id,
        :configuration_not_found,
        message: t('errors.manage_authenticator.internal_error'),
      )
    end

    def validate_has_multiple_mfa
      return if !configuration || MfaPolicy.new(user).multiple_factors_enabled?
      errors.add(
        :configuration_id,
        :only_method,
        message: t('errors.manage_authenticator.remove_only_method_error'),
      )
    end

    def extra_analytics_attributes
      { configuration_id: }
    end
  end
end
