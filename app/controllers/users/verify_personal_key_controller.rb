module Users
  class VerifyPersonalKeyController < ApplicationController
    include AccountRecoveryConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :init_account_recovery, only: [:create]

    def new
      flash.now[:notice] = t('notices.account_recovery') unless user_session[:account_recovery]

      @personal_key_form = VerifyPersonalKeyForm.new(
        user: current_user,
        personal_key: ''
      )
    end

    def create
      result = personal_key_form.submit

      if result.success?
        handle_success(result)
      else
        handle_failure(result)
      end
    end

    private

    def init_account_recovery
      user_session[:account_recovery] ||= {
        personal_key: false,
      }
    end

    def handle_success(result)
      user_session[:account_recovery][:personal_key] = true
      user_session[:decrypted_pii] = result.extra[:decrypted_pii]

      redirect_to verify_password_url
    end

    def handle_failure(result)
      flash[:error] = result.errors[:personal_key].last
      render :new
    end

    def personal_key_form
      VerifyPersonalKeyForm.new(
        user: current_user,
        personal_key: params.permit(:personal_key)[:personal_key]
      )
    end
  end
end
