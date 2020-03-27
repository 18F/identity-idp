class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  def initialize(user_agent:)
    @user_agent = user_agent
  end

  def options
    totp_option + webauthn_option + phone_options + piv_cac_option + backup_code_option
  end

  private

  def phone_options
    return [] if FeatureManagement.hide_phone_mfa_signup?
    [TwoFactorAuthentication::PhoneSelectionPresenter.new]
  end

  def webauthn_option
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new]
  end

  def totp_option
    [TwoFactorAuthentication::AuthAppSelectionPresenter.new]
  end

  def piv_cac_option
    return [] unless current_device_is_desktop?
    [TwoFactorAuthentication::PivCacSelectionPresenter.new]
  end

  def backup_code_option
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
  end

  def current_device_is_desktop?
    DeviceDetector.new(@user_agent)&.device_type == 'desktop'
  end
end
