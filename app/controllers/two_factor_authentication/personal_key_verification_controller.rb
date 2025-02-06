# frozen_string_literal: true

module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include NewDeviceConcern

    prepend_before_action :authenticate_user
    before_action :check_personal_key_enabled

    def show
      recaptcha_annotation = annotate_recaptcha(
        RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
      )
      analytics.multi_factor_auth_enter_personal_key_visit(context: context, recaptcha_annotation:)
      @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
      @personal_key_form = PersonalKeyForm.new(current_user)
    end

    def create
      @personal_key_form = PersonalKeyForm.new(current_user, personal_key_param)
      result = @personal_key_form.submit
      handle_result(result)
    end

    private

    def analytics_properties
      mfa_created_at = current_user.encrypted_recovery_code_digest_generated_at
      {
        multi_factor_auth_method: 'personal-key',
        multi_factor_auth_method_created_at: mfa_created_at&.strftime('%s%L'),
        pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
      }
    end

    def check_personal_key_enabled
      return if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?

      redirect_to authentication_methods_setup_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PersonalKeyPresenter.new
    end

    def handle_result(result)
      handle_verification_for_authentication_context(
        result:,
        auth_method: TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY,
        extra_analytics: analytics_properties,
      )

      if result.success?
        _event, disavowal_token = create_user_event_with_disavowal(:personal_key_used)
        alert_user_about_personal_key_sign_in(disavowal_token)
        remove_personal_key

        handle_valid_otp
      else
        handle_invalid_otp(type: 'personal_key')
      end
    end

    def alert_user_about_personal_key_sign_in(disavowal_token)
      response = UserAlerts::AlertUserAboutPersonalKeySignIn.call(current_user, disavowal_token)
      analytics.personal_key_alert_about_sign_in(**response)
    end

    def remove_personal_key
      # for now we will regenerate a key and not show it to them so retire personal key page shows
      PersonalKeyGenerator.new(current_user).generate!
      user_session.delete(:personal_key)
    end

    def personal_key_param
      params[:personal_key_form][:personal_key]
    end

    def handle_valid_otp
      if current_user.identity_verified? || current_user.password_reset_profile.present?
        redirect_to manage_personal_key_url
      elsif MfaPolicy.new(current_user).two_factor_enabled? &&
            !FeatureManagement.enable_additional_mfa_redirect_for_personal_key_mfa?
        redirect_to after_mfa_setup_path
      else
        redirect_to authentication_methods_setup_url
      end
    end
  end
end
