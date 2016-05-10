ConfirmationEmailHandler = Struct.new(:user) do
  def send_confirmation_email_if_needed
    return if UserDecorator.new(user).email_already_taken?

    return unless !user.pending_reconfirmation? && user.email_changed?

    postpone_email_change_until_confirmation_and_regenerate_confirmation_token
    send_confirmation_instructions
  end

  private

  # The methods below are modified versions of Devise's Confirmable module.
  # These methods are necessary in the scenario where a user needs to confirm
  # their new email, but they also have a "mobile already taken" error, which
  # prevents the Devise code from running because the user is not valid.
  # Therefore, we need to update the user attributes directly and bypass
  # validations and callbacks.
  def postpone_email_change_until_confirmation_and_regenerate_confirmation_token
    user.update_columns(unconfirmed_email: user.changes['email'][1])

    generate_confirmation_token
  end

  def generate_confirmation_token
    raw, = Devise.token_generator.generate(User, :confirmation_token)
    user.update_columns(confirmation_token: raw)
    user.update_columns(confirmation_sent_at: Time.now.utc)
  end

  def send_confirmation_instructions
    opts = { to: user.unconfirmed_email }
    user.send_devise_notification(:confirmation_instructions, user.confirmation_token, opts)
  end
end
