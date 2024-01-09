module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user
    before_action :check_personal_key_enabled

    def show
      analytics.multi_factor_auth_enter_personal_key_visit(context: context)
      @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
      @personal_key_form = PersonalKeyForm.new(current_user)
    end

    def create
      @personal_key_form = PersonalKeyForm.new(current_user, personal_key_param)
      result = @personal_key_form.submit

      track_analytics(result)
      handle_result(result)
    end

    private

    def track_analytics(result)
      mfa_created_at = current_user.encrypted_recovery_code_digest_generated_at
      analytics_hash = result.to_h.merge(
        multi_factor_auth_method: 'personal-key',
        multi_factor_auth_method_created_at: mfa_created_at&.strftime('%s%L'),
      )

      analytics.track_mfa_submit_event(analytics_hash)
    end

    def check_personal_key_enabled
      return if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?

      redirect_to authentication_methods_setup_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PersonalKeyPresenter.new
    end

    def handle_result(result)
      if result.success?
        _event, disavowal_token = create_user_event_with_disavowal(:personal_key_used)
        alert_user_about_personal_key_sign_in(disavowal_token)
        remove_personal_key

        handle_valid_otp
      else
        handle_invalid_otp(context: context, type: 'personal_key')
      end
    end

    def alert_user_about_personal_key_sign_in(disavowal_token)
      response = UserAlerts::AlertUserAboutPersonalKeySignIn.call(current_user, disavowal_token)
      analytics.personal_key_alert_about_sign_in(**response.to_h)
    end

    def remove_personal_key
      # for now we will regenerate a key and not show it to them so retire personal key page shows
      current_user.personal_key = PersonalKeyGenerator.new(current_user).create
      current_user.save!
      user_session.delete(:personal_key)
    end

    def personal_key_param
      params[:personal_key_form][:personal_key]
    end

    def handle_valid_otp
      handle_valid_verification_for_authentication_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY,
      )
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
