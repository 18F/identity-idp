module Users
  class PasswordsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :capture_password_if_pii_requested_but_locked

    def edit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
      @forbidden_passwords = current_user.email_addresses.flat_map do |email_address|
        ForbiddenPasswords.new(email_address.email).call
      end
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

    def capture_password_if_pii_requested_but_locked
      return unless current_user.decorate.identity_verified? &&
                    !Pii::Cacher.new(current_user, user_session).exists_in_session?
      user_session[:stored_location] = request.url
      redirect_to capture_password_url
    end

    def user_params
      params.require(:update_user_password_form).permit(:password)
    end

    def handle_valid_password
      create_event_and_notify_user_about_password_change
      bypass_sign_in current_user

      flash[:personal_key] = @update_user_password_form.personal_key
      redirect_to account_url, flash: { info: t('notices.password_changed') }
    end

    def create_event_and_notify_user_about_password_change
      event = create_user_event_with_disavowal(:password_changed)
      UserAlerts::AlertUserAboutPasswordChange.call(current_user, event.disavowal_token)
    end

    def handle_invalid_password
      # If the form is submitted with a password that's too short (based on
      # our Devise config) but that zxcvbn treats as strong enough, then we
      # need to provide our custom forbidden passwords data that zxcvbn needs,
      # otherwise the JS will throw an exception and the password strength
      # meter will not appear.
      @forbidden_passwords = current_user.email_addresses.flat_map do |email_address|
        ForbiddenPasswords.new(email_address.email).call
      end
      render :edit
    end
  end
end
