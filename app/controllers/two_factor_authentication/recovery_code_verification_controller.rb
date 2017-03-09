module TwoFactorAuthentication
  class RecoveryCodeVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user
    skip_before_action :handle_two_factor_authentication

    def show
      @recovery_code_form = RecoveryCodeForm.new(current_user)
    end

    def create
      @recovery_code_form = RecoveryCodeForm.new(current_user, personal_key)
      result = @recovery_code_form.submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h)

      handle_result(result)
    end

    private

    def handle_result(result)
      if result.success?
        re_encrypt_profile_recovery_pii if password_reset_profile.present?
        handle_valid_otp
      else
        handle_invalid_otp(type: 'recovery_code')
      end
    end

    def re_encrypt_profile_recovery_pii
      Pii::ReEncryptor.new(pii: pii, profile: password_reset_profile).perform
      session[:new_recovery_code] = password_reset_profile.recovery_code
    end

    def password_reset_profile
      @_password_reset_profile ||= current_user.password_reset_profile
    end

    def pii
      @_pii ||= password_reset_profile.recover_pii(personal_key)
    end

    def personal_key
      params[:recovery_code_form].require(:code).join(' ')
    end
  end
end
