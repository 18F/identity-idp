module Users
  class PasswordsController < Devise::PasswordsController
    include ValidEmailParameter

    def create
      RequestPasswordReset.new(downcased_email).perform

      analytics_user = User.find_by_email(downcased_email) || NonexistentUser.new
      analytics.track_event(
        Analytics::PASSWORD_RESET_REQUEST, user_id: analytics_user.uuid, role: analytics_user.role
      )

      redirect_to new_user_session_path, notice: t('notices.password_reset')
    end

    def edit
      if token_user&.reset_password_period_valid?
        resource = User.new
        resource.reset_password_token = params[:reset_password_token]
        @password_form = PasswordForm.new(resource)
      else
        handle_invalid_token
        redirect_to new_user_password_path
      end
    end

    # PUT /resource/password
    def update
      self.resource = User.reset_password_by_token(form_params)

      @password_form = PasswordForm.new(resource)

      if @password_form.submit(user_params)
        handle_successful_password_reset
      else
        handle_unsuccessful_password_reset
      end
    end

    protected

    def token_user
      @_token_user ||= User.with_reset_password_token(params[:reset_password_token])
    end

    def handle_invalid_token
      if token_user.blank?
        handle_no_user_matches_token
      elsif !token_user.reset_password_period_valid?
        handle_expired_token(token_user)
      end
    end

    def handle_no_user_matches_token
      analytics.track_event(
        Analytics::PASSWORD_RESET_INVALID_TOKEN, token: params[:reset_password_token]
      )
      flash[:error] = t('devise.passwords.invalid_token')
    end

    def handle_expired_token(user)
      analytics.track_event(Analytics::PASSWORD_RESET_TOKEN_EXPIRED, user_id: user.uuid)
      flash[:error] = t('devise.passwords.token_expired')
    end

    def handle_successful_password_reset
      mark_profile_inactive

      analytics.track_event(Analytics::PASSWORD_RESET_SUCCESSFUL, user_id: resource.uuid)

      flash[:notice] = t('devise.passwords.updated_not_active') if is_flashing_format?

      redirect_to new_user_session_path

      EmailNotifier.new(resource).send_password_changed_email
    end

    def handle_unsuccessful_password_reset
      if resource.errors[:reset_password_token].present?
        handle_expired_token(resource)
        redirect_to new_user_password_path
        return
      end

      analytics.track_event(Analytics::PASSWORD_RESET_INVALID_PASSWORD, user_id: resource.uuid)
      render :edit
    end

    def mark_profile_inactive
      active_profile = resource.active_profile
      return unless active_profile.present?
      active_profile.update!(active: false)
      analytics.track_event(
        Analytics::PASSWORD_RESET_DEACTIVATED_ACCOUNT,
        user_id: resource.uuid
      )
    end

    def user_params
      params.require(:password_form).
        permit(:password, :reset_password_token)
    end

    def form_params
      params.fetch(:password_form, {})
    end

    def downcased_email
      params[:user][:email].downcase
    end
  end
end
