class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user

  def initialize(user_agent:, user: nil, aal3_required: false, piv_cac_required: false)
    @user_agent = user_agent
    @user = user
    @aal3_required = aal3_required
    @piv_cac_required = piv_cac_required
  end

  def options
    webauthn_platform_option + webauthn_option + piv_cac_option + totp_option +
      phone_options + backup_code_option
  end

  def icon
    return 'icon-lock-alert-important.svg' if piv_cac_required? ||
                                              (aal3_only? && mfa_policy.two_factor_enabled?)
  end

  def icon_alt_text
    t('two_factor_authentication.important_alert_icon')
  end

  def heading
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice')
    elsif aal3_only? && mfa_policy.two_factor_enabled?
      t('two_factor_authentication.two_factor_aal3_choice')
    else
      t('two_factor_authentication.two_factor_choice')
    end
  end

  def intro
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice_intro')
    elsif aal3_only?
      t('two_factor_authentication.two_factor_aal3_choice_intro')
    elsif IdentityConfig.store.select_multiple_mfa_options
      t('mfa.info')
    else
      t('two_factor_authentication.two_factor_choice_intro')
    end
  end

  private

  def piv_cac_option
    return [] unless current_device_is_desktop?
    [TwoFactorAuthentication::PivCacSelectionPresenter.new(user: user)]
  end

  def webauthn_option
    return [] if piv_cac_required?
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new(user: user)]
  end

  def webauthn_platform_option
    return [] if piv_cac_required? || !IdentityConfig.store.platform_authentication_enabled
    [TwoFactorAuthentication::WebauthnPlatformSelectionPresenter.new(user: user)]
  end

  def phone_options
    return [] if piv_cac_required? || aal3_only? || IdentityConfig.store.hide_phone_mfa_signup
    [TwoFactorAuthentication::PhoneSelectionPresenter.new(user: user)]
  end

  def totp_option
    return [] if piv_cac_required? || aal3_only?
    [TwoFactorAuthentication::AuthAppSelectionPresenter.new(user: user)]
  end

  def backup_code_option
    return [] if piv_cac_required? || aal3_only?
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new(user: user)]
  end

  def current_device_is_desktop?
    !BrowserCache.parse(@user_agent).mobile?
  end

  def piv_cac_required?
    @piv_cac_required
  end

  def aal3_only?
    @aal3_required && !mfa_policy.aal3_mfa_enabled?
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(user)
  end
end
