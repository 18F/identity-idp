module Users
  class ResetPasswordsController < Devise::PasswordsController
    include ValidEmailParameter

    def create
      RequestPasswordReset.new(downcased_email).perform

      analytics_user = User.find_with_email(downcased_email) || NonexistentUser.new
      analytics.track_event(
        Analytics::PASSWORD_RESET_EMAIL, user_id: analytics_user.uuid, role: analytics_user.role
      )

      redirect_to new_user_session_path, notice: t('notices.password_reset')
    end

    def edit
      result = PasswordResetTokenValidator.new(token_user(params)).submit

      analytics.track_event(Analytics::PASSWORD_RESET_TOKEN, result)

      if result[:success]
        @reset_password_form = ResetPasswordForm.new(build_user)
      else
        flash[:error] = t("devise.passwords.#{result[:error]}")
        redirect_to new_user_password_path
      end
    end

    # PUT /resource/password
    def update
      self.resource = user_matching_token(user_params[:reset_password_token])

      @reset_password_form = ResetPasswordForm.new(resource)

      result = @reset_password_form.submit(user_params)

      analytics.track_event(Analytics::PASSWORD_RESET_PASSWORD, result)

      if result[:success]
        handle_successful_password_reset
      else
        handle_unsuccessful_password_reset(result)
      end
    end

    protected

    def user_matching_token(token)
      reset_password_token = Devise.token_generator.digest(User, :reset_password_token, token)

      user = User.find_or_initialize_with_error_by(:reset_password_token, reset_password_token)
      user.reset_password_token = token if user.reset_password_token.present?
      user
    end

    def token_user(params)
      @_token_user ||= User.with_reset_password_token(params[:reset_password_token])
    end

    def build_user
      User.new(reset_password_token: params[:reset_password_token])
    end

    def handle_successful_password_reset
      resource.update(password: user_params[:password])

      mark_profile_inactive

      flash[:notice] = t('devise.passwords.updated_not_active') if is_flashing_format?

      redirect_to new_user_session_path

      EmailNotifier.new(resource).send_password_changed_email
    end

    def handle_unsuccessful_password_reset(result)
      if result[:errors].include?('token_expired')
        flash[:error] = t('devise.passwords.token_expired')
        redirect_to new_user_password_path
        return
      end

      render :edit
    end

    def mark_profile_inactive
      resource.active_profile&.deactivate(:password_reset)
    end

    def user_params
      params.require(:reset_password_form).
        permit(:password, :reset_password_token)
    end

    def downcased_email
      params[:user][:email].downcase
    end
  end
end
