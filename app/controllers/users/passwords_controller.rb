module Users
  class PasswordsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
      @forbidden_passwords = ForbiddenPasswords.new(current_user.email_address.email).call
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(current_user, user_session)

      result = @update_user_password_form.submit(user_params)

      analytics.track_event(Analytics::PASSWORD_CHANGED, result.to_h)

      if result.success?
        handle_valid_password
      else
        handle_invalid_password
      end
    end

    private

    def user_params
      params.require(:update_user_password_form).permit(:password)
    end

    def handle_valid_password
      create_user_event(:password_changed)
      bypass_sign_in current_user

      flash[:personal_key] = @update_user_password_form.personal_key
      redirect_to account_url, notice: t('notices.password_changed')
    end

    def handle_invalid_password
      # If the form is submitted with a password that's too short (based on
      # our Devise config) but that zxcvbn treats as strong enough, then we
      # need to provide our custom forbidden passwords data that zxcvbn needs,
      # otherwise the JS will throw an exception and the password strength
      # meter will not appear.
      @forbidden_passwords = ForbiddenPasswords.new(current_user.email).call
      render :edit
    end
  end
end
