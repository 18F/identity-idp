module TwoFactorAuthentication
  class BackupCodeVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user
    before_action :check_sp_required_mfa_bypass

    def show
      analytics.multi_factor_auth_enter_backup_code_visit(context: context)
      @presenter = TwoFactorAuthCode::BackupCodePresenter.new(
        view: view_context,
        data: { current_user: current_user },
        service_provider: current_sp,
        remember_device_default: remember_device_default,
      )
      @backup_code_form = BackupCodeVerificationForm.new(current_user)
    end

    def create
      @backup_code_form = BackupCodeVerificationForm.new(current_user)
      result = @backup_code_form.submit(backup_code_params)
      analytics.track_mfa_submit_event(result.to_h)
      irs_attempts_api_tracker.mfa_verify_backup_code(success: result.success?)
      handle_result(result)
    end

    private

    def all_codes_used?
      current_user.backup_code_configurations.unused.none?
    end

    def handle_last_code
      generator = BackupCodeGenerator.new(current_user)
      generator.delete_existing_codes
      user_session[:backup_codes] = generator.generate
      generator.save(user_session[:backup_codes])
      flash[:info] = t('forms.backup_code.last_code')
      redirect_to backup_code_refreshed_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::BackupCodePresenter.new(
        view: view_context,
        data: { current_user: current_user },
        service_provider: current_sp,
      )
    end

    def handle_invalid_backup_code
      update_invalid_user

      flash.now[:error] = t('two_factor_authentication.invalid_backup_code')

      if decorated_user.locked_out?
        handle_second_factor_locked_user('backup_code')
      else
        render_show_after_invalid
      end
    end

    def handle_result(result)
      if result.success?
        handle_valid_otp_for_authentication_context
        return handle_last_code if all_codes_used?
        handle_valid_backup_code
      else
        handle_invalid_backup_code
      end
    end

    def backup_code_params
      params.require(:backup_code_verification_form).permit :backup_code
    end

    def handle_valid_backup_code
      redirect_to after_otp_verification_confirmation_url
      reset_otp_session_data
    end
  end
end
