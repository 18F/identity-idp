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
      analytics_hash = result.to_h.merge(multi_factor_auth_method: 'personal-key')

      analytics.track_mfa_submit_event(analytics_hash)

      handle_result(result)
    end

    private

    def check_personal_key_enabled
      return if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?

      redirect_to authentication_methods_setup_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PersonalKeyPresenter.new
    end

    def handle_result(result)
      if result.success?
        event = create_user_event_with_disavowal(:personal_key_used)
        alert_user_about_personal_key_sign_in(event)
        generate_new_personal_key_for_verified_users_otherwise_retire_the_key_and_ensure_two_mfa
        handle_valid_otp
      else
        handle_invalid_otp(context: context, type: 'personal_key')
      end
    end

    def alert_user_about_personal_key_sign_in(event)
      response = UserAlerts::AlertUserAboutPersonalKeySignIn.call(
        current_user, event.disavowal_token
      )
      analytics.personal_key_alert_about_sign_in(**response.to_h)
    end

    def generate_new_personal_key_for_verified_users_otherwise_retire_the_key_and_ensure_two_mfa
      if password_reset_profile.present?
        re_encrypt_profile_recovery_pii
      elsif decorated_user.identity_verified?
        user_session[:personal_key] = PersonalKeyGenerator.new(current_user).create
      else
        remove_personal_key
      end
    end

    def remove_personal_key
      # for now we will regenerate a key and not show it to them so retire personal key page shows
      current_user.personal_key = PersonalKeyGenerator.new(current_user).create
      current_user.save!
      user_session.delete(:personal_key)
    end

    def re_encrypt_profile_recovery_pii
      analytics.personal_key_reactivation_sign_in
      Pii::ReEncryptor.new(pii: pii, profile: password_reset_profile).perform
      user_session[:personal_key] = password_reset_profile.personal_key
    end

    def password_reset_profile
      @password_reset_profile ||= current_user.decorate.password_reset_profile
    end

    def pii
      @pii ||= password_reset_profile.recover_pii(normalized_personal_key)
    end

    def personal_key_param
      params[:personal_key_form][:personal_key]
    end

    def normalized_personal_key
      @personal_key_form.personal_key
    end

    def handle_valid_otp
      handle_valid_otp_for_authentication_context
      if decorated_user.identity_verified? || decorated_user.password_reset_profile.present?
        redirect_to manage_personal_key_url
      elsif MfaPolicy.new(current_user).two_factor_enabled?
        redirect_to after_mfa_setup_path
      else
        redirect_to authentication_methods_setup_url
      end
      reset_otp_session_data
    end
  end
end
