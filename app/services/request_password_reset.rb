RequestPasswordReset = RedactedStruct.new(
  :email, :request_id, :analytics, keyword_init: true,
                                   allowed_members: [:request_id]
) do
  def perform
    if user_should_receive_registration_email?
      form = RegisterUserEmailForm.new(password_reset_requested: true, analytics: analytics)
      result = form.submit({ email: email, terms_accepted: '1' }, instructions)
      [form.user, result]
    else
      send_reset_password_instructions
      nil
    end
  end

  private

  def send_reset_password_instructions
    if Throttle.new(user: user, throttle_type: :reset_password_email).throttled_else_increment?
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :reset_password_email,
      )
    else
      token = user.set_reset_password_token
      UserMailer.reset_password_instructions(user, email, token: token).deliver_now_or_later

      event = PushNotification::RecoveryActivatedEvent.new(user: user)
      PushNotification::HttpPush.deliver(event)
    end
  end

  def instructions
    I18n.t(
      'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
      app_name: APP_NAME,
    )
  end

  ##
  # If a user record does not exist for an email address, we send a registration
  # email instead of a reset email so the user can go through the account
  # creation process without having to receive another email
  #
  # If a user exists but does not have any confirmed email addresses, we send
  # them a reset email so they can set the password on the account
  #
  # If a user exists and has a confirmed email addresses, but this email address
  # is not confirmed we should not let them reset the password with this email
  # address. Instead we send them an email to create an account with the
  # unconfirmed email address
  ##
  def user_should_receive_registration_email?
    return true if user.nil?
    return false unless user.confirmed?
    return false if email_address_record.confirmed?
    true
  end

  def user
    @user ||= email_address_record&.user
  end

  def email_address_record
    @email_address_record ||= begin
      EmailAddress.confirmed.find_with_email(email) ||
        EmailAddress.unconfirmed.find_with_email(email)
    end
  end
end
