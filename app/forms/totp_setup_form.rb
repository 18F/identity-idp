class TotpSetupForm
  def initialize(user, secret, code)
    @user = user
    @secret = secret
    @code = code
  end

  def submit
    @success = valid_totp_code?

    process_valid_submission if success

    FormResponse.new(success: success, errors: {})
  end

  private

  attr_reader :user, :code, :secret, :success

  def valid_totp_code?
    user.confirm_totp_secret(secret, code)
  end

  def process_valid_submission
    user.save!
    Event.create(user_id: user.id, event_type: :authenticator_enabled)
  end
end
