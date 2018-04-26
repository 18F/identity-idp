module Users
  class PasswordsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
      @forbidden_passwords = ForbiddenPasswords.new(current_user.email).call
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(current_user, user_session)

      result = @update_user_password_form.submit(user_params)

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
      create_user_event(:password_changed)
      bypass_sign_in current_user

      flash[:personal_key] = @update_user_password_form.personal_key
      redirect_to account_url, notice: t('notices.password_changed')
    end
  end
end
