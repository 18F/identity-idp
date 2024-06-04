# frozen_string_literal: true

module TwoFactorAuthentication
  class BackupCodeVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include NewDeviceConcern

    prepend_before_action :authenticate_user
    before_action :check_sp_required_mfa

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
      analytics.multi_factor_auth(**result.to_h.merge(new_device: new_device?))
      handle_result(result)
    end

    private

    def all_codes_used?
      current_user.backup_code_configurations.unused.none?
    end

    def handle_last_code
      generator = BackupCodeGenerator.new(current_user)
      user_session[:backup_codes] = generator.delete_and_regenerate
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
      handle_invalid_verification_for_authentication_context
      update_invalid_user

      flash.now[:error] = t('two_factor_authentication.invalid_backup_code')

      if current_user.locked_out?
        handle_second_factor_locked_user(type: 'backup_code')
      else
        render_show_after_invalid
      end
    end

    def handle_result(result)
      if result.success?
        handle_remember_device_preference(backup_code_params[:remember_device])
        handle_valid_verification_for_authentication_context(
          auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
        )
        return handle_last_code if all_codes_used?
        handle_valid_backup_code
      else
        handle_invalid_backup_code
      end
    end

    def backup_code_params
      params.require(:backup_code_verification_form).permit(:backup_code, :remember_device)
    end

    def handle_valid_backup_code
      redirect_to after_sign_in_path_for(current_user)
    end

    def check_sp_required_mfa
      check_sp_required_mfa_bypass(auth_method: 'backup_code')
    end
  end
end
