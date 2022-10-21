module Users
  class ResetPasswordsController < Devise::PasswordsController
    def new
      analytics.password_reset_visit
      @password_reset_email_form = PasswordResetEmailForm.new('')
    end

    def create
      @password_reset_email_form = PasswordResetEmailForm.new(email)
      result = @password_reset_email_form.submit

      analytics.password_reset_email(**result.to_h)

      if result.success?
        handle_valid_email
      else
        render :new
      end
    end

    def edit
      result = PasswordResetTokenValidator.new(token_user).submit

      analytics.password_reset_token(**result.to_h)
      irs_attempts_api_tracker.forgot_password_email_confirmed(
        success: result.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )

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

      analytics.password_reset_password(**result.to_h)
      irs_attempts_api_tracker.forgot_password_new_password_submitted(
        success: result.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )

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
      user, result = RequestPasswordReset.new(
        email: email,
        request_id: request_id,
        analytics: analytics,
        irs_attempts_api_tracker: irs_attempts_api_tracker,
      ).perform

      return unless result

      analytics.user_registration_email(**result.to_h)
      irs_attempts_api_tracker.user_registration_email_submitted(
        email: email,
        success: result.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )
      create_user_event(:account_created, user)
    end

    def handle_invalid_or_expired_token(result)
      flash[:error] = t("devise.passwords.#{result.errors[:user].first}")
      redirect_to new_user_password_url
    end

    def user_matching_token(token)
      reset_password_token = Devise.token_generator.digest(User, :reset_password_token, token)

      user = User.find_or_initialize_with_error_by(:reset_password_token, reset_password_token)
      user.reset_password_token = token if user.reset_password_token?
      user
    end

    def token_user
      @token_user ||= User.with_reset_password_token(params[:reset_password_token])
    end

    def build_user
      User.new(reset_password_token: params[:reset_password_token])
    end

    def handle_successful_password_reset
      send_password_reset_risc_event
      create_reset_event_and_send_notification
      flash[:info] = t('devise.passwords.updated_not_active') if is_flashing_format?
      redirect_to new_user_session_url
    end

    def send_password_reset_risc_event
      event = PushNotification::PasswordResetEvent.new(user: resource)
      PushNotification::HttpPush.deliver(event)
    end

    def handle_unsuccessful_password_reset(result)
      reset_password_token_errors = result.errors[:reset_password_token]
      if reset_password_token_errors.present?
        flash[:error] = t("devise.passwords.#{reset_password_token_errors.first}")
        redirect_to new_user_password_url
        return
      end

      @forbidden_passwords = forbidden_passwords(resource.email_addresses)
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
