module Users
  class PasswordsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
    end

    def update
      @update_user_password = UpdateUserPassword.new(
        user: current_user, user_session: user_session, password: user_params[:password]
      )
      result = @update_user_password.call

      analytics.track_event(Analytics::PASSWORD_CHANGED, result.to_h)

      if result.success?
        handle_success
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:update_user_password_form).permit(:password)
    end

    def handle_success
      bypass_sign_in current_user

      flash[:personal_key] = @update_user_password.personal_key
      redirect_to account_url, notice: t('notices.password_changed')
    end
  end
end
