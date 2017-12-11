module TwoFactorAuthentication
  class PersonalKeyVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user

    def show
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
        re_encrypt_profile_recovery_pii if password_reset_profile.present?
        handle_valid_otp
      else
        handle_invalid_otp(type: 'personal_key')
      end
    end

    def re_encrypt_profile_recovery_pii
      Pii::ReEncryptor.new(pii: pii, profile: password_reset_profile).perform
      session[:new_personal_key] = password_reset_profile.personal_key
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
  end
end
