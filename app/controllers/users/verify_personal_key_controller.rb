module Users
  class VerifyPersonalKeyController < ApplicationController
    include AccountReactivationConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :init_account_reactivation, only: [:new]

    def new
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

    def init_account_reactivation
      return if reactivate_account_session.started?

      flash.now[:notice] = t('notices.account_reactivation')
      reactivate_account_session.start
    end

    def handle_success(result)
      reactivate_account_session.store_decrypted_pii(result.extra[:decrypted_pii])
      redirect_to verify_password_url
    end

    def handle_failure(result)
      flash.now[:error] = result.errors[:personal_key].last
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
