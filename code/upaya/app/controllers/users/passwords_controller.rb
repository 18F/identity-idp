module Users
  class PasswordsController < Devise::PasswordsController
    include ValidEmailParameter

    before_action :confirm_valid_token, only: [:edit]
    before_action :check_if_security_questions_required, only: [:edit]

    rescue_from Pundit::NotAuthorizedError do |_exception|
      # We are utilizing Pundit's policy for verifying which user can
      # recover passwords. However, we always want to return success.
      flash[:success] = t('upaya.notices.password_reset')
      redirect_to after_sending_reset_password_instructions_path_for(
        resource_name)
    end

    def create
      resource = resource_class.find_by_email(resource_params[:email])

      if resource

        authorize resource, :recover_password?

        if resource.confirmed_at.nil?
          # If the account has not been confirmed, password reset should resend
          # the confirmation email instructions
          self.resource = resource_class.send_confirmation_instructions(
            resource_params)
        else
          # only send_reset_password_instructions if resource is matched above.
          # this disallows other roles from using the password recovery form.
          self.resource = resource_class.send_reset_password_instructions(
            resource_params)
        end
      end

      flash[:success] = t('upaya.notices.password_reset')
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    end

    # PUT /resource/password
    def update
      self.resource = resource_class.reset_password_by_token(resource_params)

      return handle_successful_password_reset_for(resource) if resource.errors.empty?

      return handle_expired_reset_password_token unless resource.reset_password_period_valid?

      handle_failed_password_reset_for(resource)
    end

    protected

    def token_user
      User.with_reset_password_token(params[:reset_password_token])
    end

    def confirm_valid_token
      return if token_user.present? && token_user.reset_password_period_valid?

      flash[:error] =
        if token_user.blank?
          t('devise.passwords.invalid_token')
        elsif !token_user.reset_password_period_valid?
          t('devise.passwords.token_expired')
        end

      redirect_to new_user_password_path
    end

    def check_if_security_questions_required
      return unless token_user.security_questions_enabled?
      redirect_to users_questions_confirm_path(
        reset_password_token: params[:reset_password_token])
    end

    def handle_successful_password_reset_for(resource)
      resource.unlock_access! if unlockable?(resource)

      set_flash_message(:notice, :updated_not_active) if is_flashing_format?

      respond_with resource, location: after_resetting_password_path_for(resource)

      EmailNotifier.new(resource).send_password_changed_email
    end

    def handle_expired_reset_password_token
      set_flash_message(:error, :token_expired) if is_flashing_format?

      redirect_to new_user_password_path
    end

    def handle_failed_password_reset_for(resource)
      set_minimum_password_length
      respond_with resource
    end
  end
end
