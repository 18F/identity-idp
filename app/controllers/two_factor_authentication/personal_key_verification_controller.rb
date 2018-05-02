module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user

    def show
      analytics.track_event(
        Analytics::MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT, context: context
      )

      @personal_key_form = PersonalKeyForm.new(current_user)
    end

    def create
      @personal_key_form = PersonalKeyForm.new(current_user, personal_key_param)
      result = @personal_key_form.submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h)

      handle_result(result)
    end

    private

    def handle_result(result)
      if result.success?
        generate_new_personal_key
        handle_valid_otp
      else
        handle_invalid_otp(type: 'personal_key')
      end
    end

    def generate_new_personal_key
      if password_reset_profile.present?
        re_encrypt_profile_recovery_pii
      else
        user_session[:personal_key] = PersonalKeyGenerator.new(current_user).create
      end
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

    def handle_valid_otp
      handle_valid_otp_for_authentication_context
      redirect_to manage_personal_key_url
      reset_otp_session_data
    end
  end
end
