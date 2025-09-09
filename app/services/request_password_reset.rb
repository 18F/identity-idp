# frozen_string_literal: true

RequestPasswordReset = RedactedStruct.new(
  :email, :request_id, :analytics, :attempts_api_tracker,
  keyword_init: true,
  allowed_members: [:request_id]
) do
  def perform
    rate_limiter = RateLimiter.new(target: email, rate_limit_type: :reset_password_email)
    rate_limiter.increment!
    if rate_limiter.limited?
      analytics.rate_limit_reached(limiter_type: :reset_password_email)
    elsif user.blank?
      AnonymousMailer.with(email:).password_reset_missing_user(request_id:).deliver_now
    elsif user.suspended?
      UserMailer.with(
        user: user,
        email_address: email_address_record,
      ).suspended_reset_password.deliver_now_or_later
    else
      token = user.set_reset_password_token
      UserMailer.with(user: user, email_address: email_address_record).reset_password_instructions(
        token: token,
        request_id: request_id,
      ).deliver_now_or_later

      event = PushNotification::RecoveryActivatedEvent.new(user: user)
      PushNotification::HttpPush.deliver(event)

      attempts_api_tracker.forgot_password_email_sent(email:)
    end
  end

  private

  def user
    @user ||= email_address_record&.user
  end

  def email_address_record
    @email_address_record ||= EmailAddress.confirmed.find_with_email(email)
  end
end.freeze
