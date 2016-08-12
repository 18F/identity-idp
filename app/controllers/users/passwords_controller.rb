module Users
  class PasswordsController < Devise::PasswordsController
    include ValidEmailParameter

    before_action :confirm_valid_token, only: [:edit]

    def create
      RequestPasswordReset.new(params[:user][:email]).perform

      flash[:success] = t('notices.password_reset')
      redirect_to new_user_session_path
    end

    def edit
      resource = User.new
      resource.reset_password_token = params[:reset_password_token]
      @password_form = PasswordForm.new(resource)
    end

    # PUT /resource/password
    def update
      self.resource = User.reset_password_by_token(form_params)

      @password_form = PasswordForm.new(resource)

      if @password_form.submit(user_params)
        handle_successful_password_reset_for(resource)
      else
        if resource.errors[:reset_password_token].present?
          return handle_expired_reset_password_token
        end

        render :edit
      end
    end

    protected

    def token_user
      @token_user ||= User.with_reset_password_token(params[:reset_password_token])
    end

    def confirm_valid_token
      return if token_user.present? && reset_password_period_valid?

      flash[:error] =
        if token_user.blank?
          t('devise.passwords.invalid_token')
        elsif !reset_password_period_valid?
          t('devise.passwords.token_expired')
        end

      redirect_to new_user_password_path
    end

    def reset_password_period_valid?
      token_user.reset_password_period_valid?
    end

    def handle_successful_password_reset_for(resource)
      analytics.track_event('Password reset', resource)

      flash[:notice] = t('devise.passwords.updated_not_active') if is_flashing_format?

      redirect_to new_user_session_path

      EmailNotifier.new(resource).send_password_changed_email
    end

    def handle_expired_reset_password_token
      flash[:error] = t('devise.passwords.token_expired') if is_flashing_format?

      redirect_to new_user_password_path
    end

    def user_params
      params.require(:password_form).
        permit(:password, :reset_password_token)
    end

    def form_params
      params.fetch(:password_form, {})
    end
  end
end
