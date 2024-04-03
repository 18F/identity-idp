# frozen_string_literal: true

class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    cfg = if_valid_totp_code_return_config
    FormResponse.new(
      success: cfg.present?,
      extra: extra_analytics_attributes(cfg),
    )
  end

  private

  attr_reader :user, :code

  def if_valid_totp_code_return_config
    return unless code.match? pattern_matching_totp_code_format
    Db::AuthAppConfiguration.authenticate(user, code)
  end

  def pattern_matching_totp_code_format
    /\A\d{#{totp_code_length}}\Z/
  end

  def totp_code_length
    TwoFactorAuthenticatable::OTP_LENGTH
  end

  def extra_analytics_attributes(cfg)
    {
      multi_factor_auth_method: 'totp',
      auth_app_configuration_id: cfg&.id,
      multi_factor_auth_method_created_at: cfg&.created_at&.strftime('%s%L'),
    }
  end
end
