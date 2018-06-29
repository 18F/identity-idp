class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
    @configuration_manager = TwoFactorAuthentication::TotpConfigurationManager.new(user)
  end

  def submit
    FormResponse.new(success: valid_totp_code?, errors: {}, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :code, :configuration_manager

  def valid_totp_code?
    configuration_manager.authenticate(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'totp',
    }
  end
end
