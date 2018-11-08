module Users
  class RecoveryCodeSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def new
      @presenter = TwoFactorAuthCode::RecoveryCodePresenter.new(data: {:current_user => current_user}, view: self.view_context)
      result = RecoveryCodeVisitForm.new.submit(params)
      analytics.track_event(Analytics::RECOVERY_CODE_SETUP_VISIT, result.to_h)
      flash_error(result.errors) unless result.success?
    end

    def index
      new
    end

    def confirm
      form = RecoveryCodeSetupForm.new(current_user, user_session)
      result = form.submit(request.protocol, params)
      analytics.track_event(Analytics::RECOVERY_CODE_SETUP_SUBMITTED, result.to_h)
      if result.success?
        process_valid_RecoveryCode
      else
        process_invalid_RecoveryCode(form)
      end
    end

    def success
      @next_url = url_after_successful_recovery_code_setup
    end

    def delete
      if MfaPolicy.new(current_user).multiple_factors_enabled?
        handle_successful_delete
      else
        handle_failed_delete
      end
      redirect_to account_url
    end

    def show_delete
      render 'users/recovery_code_setup/delete'
    end

    private

    def flash_error(errors)
      flash.now[:error] = errors.values.first.first
    end

    def handle_successful_delete
      create_user_event(:RecoveryCode_key_removed)
      RecoveryCodeConfiguration.where(user_id: current_user.id, id: params[:id]).destroy_all
      flash[:success] = t('notices.recovery_code_deleted')
      track_delete(true)
    end

    def handle_failed_delete
      track_delete(false)
    end

    def track_delete(success)
      counts_hash = MfaContext.new(current_user.reload).enabled_two_factor_configuration_counts_hash

      analytics.track_event(
          Analytics::RECOVERYCODE_DELETED,
          success: success,
          mfa_method_counts: counts_hash
      )
    end

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
    end

    def process_valid_recovery_code
      mark_user_as_fully_authenticated
      redirect_to recovery_code_setup_success_url
    end

    def url_after_successful_recovery_code_setup
      return account_url
    end

    def process_invalid_RecoveryCode(form)
      if form.name_taken
        flash.now[:error] = t('errors.RecoveryCode_setup.unique_name')
        render 'users/RecoveryCode_setup/new'
      else
        flash[:error] = t('errors.RecoveryCode_setup.general_error')
        redirect_to account_url
      end
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def user_already_has_a_personal_key?
      TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).configured?
    end
  end
end
