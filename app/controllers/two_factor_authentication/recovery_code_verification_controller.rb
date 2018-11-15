module TwoFactorAuthentication
  class RecoveryCodeVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user

    def show
      puts "############## IN SHOW"

      analytics.track_event(
          Analytics::MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT, context: context
      )
      @presenter = TwoFactorAuthCode::RecoveryCodePresenter.new(
          view: view_context,
          data: { current_user: current_user }
      )
      @recovery_code_form = RecoveryCodeVerificationForm.new(current_user)
    end

    def create
      @recovery_code_form = RecoveryCodeVerificationForm.new(current_user)
      result = @recovery_code_form.submit(recovery_code_params)
      puts "############## #{result}"

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h)

      handle_result(result)
    end

    private

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::RecoveryCodePresenter.new(
          view: view_context,
          data: { current_user: current_user }
      )
    end

    def handle_result(result)
      if result.success?
        # create_user_event(:recovery_code_used)
        handle_valid_recovery_code
      else
        handle_invalid_otp(type: 'recovery_code')
      end
    end

    def generate_new_recovery_codes_if_needed
      #if password_reset_profile.present?
        # re_encrypt_profile_recovery_pii
      #else
      #  user_session[:recovery_codes] = PersonalKeyGenerator.new(current_user).create
      #end
    end
    
    def recovery_code_params
      params.require(:recovery_code_verification_form).permit :recovery_code
    end

    def handle_valid_recovery_code
      handle_valid_otp_for_authentication_context
      redirect_to manage_personal_key_url
      reset_otp_session_data
      user_session.delete(:mfa_device_remembered)
    end

    def handle_invalid_recovery_code(type: 'recovery_code')
      update_invalid_user

      flash.now[:error] = t("two_factor_authentication.invalid_#{type}")

      if decorated_user.locked_out?
        handle_second_factor_locked_user(type)
      else
        render_show_after_invalid
      end
    end
  end
end
