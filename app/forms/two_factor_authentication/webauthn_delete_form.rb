# frozen_string_literal: true

module TwoFactorAuthentication
  class WebauthnDeleteForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    attr_reader :user, :configuration_id

    delegate :platform_authenticator?, to: :configuration, allow_nil: true

    validate :validate_configuration_exists
    validate :validate_has_multiple_mfa

    def initialize(user:, configuration_id:, skip_multiple_mfa_validation: false)
      @user = user
      @configuration_id = configuration_id
      @skip_multiple_mfa_validation = skip_multiple_mfa_validation
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
      @configuration ||= user.webauthn_configurations.find_by(id: configuration_id)
    end

    def event_type
      if platform_authenticator?
        :webauthn_platform_removed
      else
        :webauthn_key_removed
      end
    end

    private

    attr_reader :skip_multiple_mfa_validation

    alias_method :skip_multiple_mfa_validation?, :skip_multiple_mfa_validation

    def validate_configuration_exists
      return if configuration.present?
      errors.add(
        :configuration_id,
        :configuration_not_found,
        message: t('errors.manage_authenticator.internal_error'),
      )
    end

    def validate_has_multiple_mfa
      return if skip_multiple_mfa_validation? ||
                !configuration ||
                MfaPolicy.new(user).multiple_factors_enabled?

      errors.add(
        :configuration_id,
        :only_method,
        message: t('errors.manage_authenticator.remove_only_method_error'),
      )
    end

    def extra_analytics_attributes
      {
        configuration_id:,
        platform_authenticator: platform_authenticator?,
      }
    end
  end
end
