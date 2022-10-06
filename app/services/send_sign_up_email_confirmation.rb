class SendSignUpEmailConfirmation
  include ::NewRelic::Agent::MethodTracer

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call(request_id: nil, instructions: nil, password_reset_requested: false)
    update_email_address_record

    if password_reset_requested && !user.confirmed?
      send_pw_reset_request_unconfirmed_user_email(request_id, instructions)
    else
      send_confirmation_email(request_id, instructions)
    end
  end

  private

  def confirmation_token
    return email_address.confirmation_token if valid_confirmation_token_exists?
    @confirmation_token ||= Devise.friendly_token
  end

  def confirmation_sent_at
    return email_address.confirmation_sent_at if valid_confirmation_token_exists?
    @confirmation_sent_at ||= Time.zone.now
  end

  def confirmation_period_expired?
    @confirmation_period_expired ||= email_address.confirmation_period_expired?
  end

  def email_address
    @email_address ||= begin
      handle_multiple_email_address_error if user.email_addresses.count > 1
      user.email_addresses.take
    end
  end

  def valid_confirmation_token_exists?
    email_address.confirmation_token.present? && !confirmation_period_expired?
  end

  def update_email_address_record
    email_address.update!(
      confirmation_token: confirmation_token,
      confirmation_sent_at: confirmation_sent_at,
    )
  end

  def send_confirmation_email(request_id, instructions)
    UserMailer.with(user: user, email_address: email_address).email_confirmation_instructions(
      confirmation_token,
      request_id: request_id,
      instructions: instructions,
    ).deliver_now_or_later
  end

  def send_pw_reset_request_unconfirmed_user_email(request_id, instructions)
    UserMailer.with(user: user, email_address: email_address).unconfirmed_email_instructions(
      confirmation_token,
      request_id: request_id,
      instructions: instructions,
    ).deliver_now_or_later
  end

  def handle_multiple_email_address_error
    raise 'sign up user has multiple email address records'
  end

  add_method_tracer :call, "Custom/#{name}/call"
end
