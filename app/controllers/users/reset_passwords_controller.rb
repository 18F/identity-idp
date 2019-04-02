module Users
  class ResetPasswordsController < Devise::PasswordsController # rubocop:disable Metrics/ClassLength
    include RecaptchaConcern

    def new
      analytics.track_event(Analytics::PASSWORD_RESET_VISIT)
      @password_reset_email_form = PasswordResetEmailForm.new('')
    end

    def create
      @password_reset_email_form = PasswordResetEmailForm.new(email, validate_recaptcha)
      result = @password_reset_email_form.submit

      analytics.track_event(Analytics::PASSWORD_RESET_EMAIL, result.to_h)

      if result.success?
        handle_valid_email
      else
        render :new
      end
    end

    def edit
      result = PasswordResetTokenValidator.new(token_user).submit

      analytics.track_event(Analytics::PASSWORD_RESET_TOKEN, result.to_h)

      if result.success?
        @reset_password_form = ResetPasswordForm.new(build_user)
        @forbidden_passwords = forbidden_passwords(token_user.email_addresses)
      else
        handle_invalid_or_expired_token(result)
      end
    end

    # PUT /resource/password
    def update
      self.resource = user_matching_token(user_params[:reset_password_token])
      @reset_password_form = ResetPasswordForm.new(resource)

      result = @reset_password_form.submit(user_params)

      analytics.track_event(Analytics::PASSWORD_RESET_PASSWORD, result.to_h)

      if result.success?
        handle_successful_password_reset
      else
        handle_unsuccessful_password_reset(result)
      end
    end

    protected

    def forbidden_passwords(email_addresses)
      email_addresses.flat_map do |email_address|
        ForbiddenPasswords.new(email_address.email).call
      end
    end

    def email_params
      params.require(:password_reset_email_form).permit(:email, :resend, :request_id)
    end

    def email
      email_params[:email]
    end

    def request_id
      email_params[:request_id]
    end

    def handle_valid_email
      create_account_if_email_not_found

      session[:email] = email
      resend_confirmation = email_params[:resend]

      redirect_to forgot_password_url(resend: resend_confirmation, request_id: request_id)
    end

    def create_account_if_email_not_found
      user, result = RequestPasswordReset.new(email, request_id).perform
      return unless result

      analytics.track_event(Analytics::USER_REGISTRATION_EMAIL, result.to_h)
      create_user_event(:account_created, user)
    end

    def handle_invalid_or_expired_token(result)
      flash[:error] = t("devise.passwords.#{result.errors[:user].first}")
      redirect_to new_user_password_url
    end

    def user_matching_token(token)
      reset_password_token = Devise.token_generator.digest(User, :reset_password_token, token)

      user = User.find_or_initialize_with_error_by(:reset_password_token, reset_password_token)
      user.reset_password_token = token if user.reset_password_token.present?
      user
    end

    def token_user
      @_token_user ||= User.with_reset_password_token(params[:reset_password_token])
    end

    def build_user
      User.new(reset_password_token: params[:reset_password_token])
    end

    def handle_successful_password_reset
      create_reset_event_and_send_notification
      flash[:notice] = t('devise.passwords.updated_not_active') if is_flashing_format?
      redirect_to new_user_session_url
    end

    def handle_unsuccessful_password_reset(result)
      reset_password_token_errors = result.errors[:reset_password_token]
      if reset_password_token_errors.present?
        flash[:error] = t("devise.passwords.#{reset_password_token_errors.first}")
        redirect_to new_user_password_url
        return
      end

      render :edit
    end

    def create_reset_event_and_send_notification
      event = create_user_event_with_disavowal(:password_changed, resource)
      UserAlerts::AlertUserAboutPasswordChange.call(resource, event.disavowal_token)
    end

    def user_params
      params.require(:reset_password_form).
        permit(:password, :reset_password_token)
    end

    def assert_reset_token_passed
      # remove devise's default behavior
    end
  end
end
