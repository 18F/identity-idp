# frozen_string_literal: true

module Users
  class VerifyPasswordController < ApplicationController
    include AccountReactivationConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :confirm_personal_key

    def new
      analytics.reactivate_account_verify_password_visited
    end

    def update
      form = verify_password_form
      result = form.submit

      analytics.reactivate_account_verify_password_submitted(**result.to_h)

      if result.success?
        handle_success(personal_key: form.personal_key)
      else
        flash[:error] = t('errors.messages.password_incorrect')
        render :new
      end
    end

    private

    def confirm_personal_key
      return if reactivate_account_session.validated_personal_key?
      redirect_to root_url
    end

    def handle_success(personal_key:)
      user_session[:personal_key] = personal_key
      reactivate_account_session.clear
      redirect_to manage_personal_key_url
    end

    def verify_password_form
      VerifyPasswordForm.new(
        user: current_user,
        password: params.require(:user).permit(:password)[:password],
        decrypted_pii: reactivate_account_session.decrypted_pii,
      )
    end
  end
end
