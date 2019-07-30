module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user

    def show
      analytics.track_event(
        Analytics::MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT, context: context
      )
      @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
      @personal_key_form = PersonalKeyForm.new(current_user)
    end

    def create
      @personal_key_form = PersonalKeyForm.new(current_user, personal_key_param)
      result = @personal_key_form.submit
      analytics_hash = result.to_h.merge(multi_factor_auth_method: 'personal-key')

      analytics.track_mfa_submit_event(analytics_hash, ga_cookie_client_id)

      handle_result(result)
    end

    private

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PersonalKeyPresenter.new
    end

    def handle_result(result)
      if result.success?
        event = create_user_event_with_disavowal(:personal_key_used)
        UserAlerts::AlertUserAboutPersonalKeySignIn.call(current_user, event.disavowal_token)
        generate_new_personal_key_for_verified_users_otherwise_retire_the_key_and_ensure_two_mfa
        handle_valid_otp
      else
        handle_invalid_otp(type: 'personal_key')
      end
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
      current_user.personal_key = nil
      current_user.encrypted_recovery_code_digest = nil
      current_user.save!
      user_session.delete(:personal_key)
    end

    def re_encrypt_profile_recovery_pii
      Pii::ReEncryptor.new(pii: pii, profile: password_reset_profile).perform
      user_session[:personal_key] = password_reset_profile.personal_key
    end

    def password_reset_profile
      @_password_reset_profile ||= current_user.decorate.password_reset_profile
    end

    def pii
      @_pii ||= password_reset_profile.recover_pii(normalized_personal_key)
    end

    def personal_key_param
      params[:personal_key_form][:personal_key]
    end

    def normalized_personal_key
      @personal_key_form.personal_key
    end

    # rubocop:disable Metrics/AbcSize
    def handle_valid_otp
      handle_valid_otp_for_authentication_context
      if decorated_user.identity_verified? || decorated_user.password_reset_profile.present?
        redirect_to manage_personal_key_url
      elsif MfaPolicy.new(current_user).sufficient_factors_enabled?
        redirect_to after_multiple_2fa_sign_up
      else
        redirect_to two_factor_options_url
      end
      reset_otp_session_data
      user_session.delete(:mfa_device_remembered)
    end
    # rubocop:enable Metrics/AbcSize
  end
end
