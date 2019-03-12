class TotpSetupForm
  def initialize(user, secret, code)
    @user = user
    @secret = secret
    @code = code
  end

  def submit
    @success = valid_totp_code?

    process_valid_submission if success

    FormResponse.new(success: success, errors: {}, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :code, :secret, :success

  def valid_totp_code?
    # The two_factor_authentication gem raises an error if the secret is nil.
    return false if secret.nil?
    user.confirm_totp_secret(secret, code)
  end

  def process_valid_submission
    user.save!
  end

  def extra_analytics_attributes
    {
      totp_secret_present: secret.present?,
      multi_factor_auth_method: 'totp',
    }
  end
end
