class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  def initialize(user_agent:, user: nil, aal3_required: false, piv_cac_only_required: false)
    @user_agent = user_agent
    @user = user
    @aal3_required = aal3_required
    @piv_cac_only_required = piv_cac_only_required
  end

  def options
    totp_option + webauthn_option + phone_options + piv_cac_option + backup_code_option
  end

  def icon
    return 'icon-lock-alert-important.svg' if piv_cac_only_required? ||
                                              (aal3_only? && mfa_policy.two_factor_enabled?)
  end

  def heading
    if piv_cac_only_required?
      t('two_factor_authentication.two_factor_hspd12_choice')
    elsif aal3_only? && mfa_policy.two_factor_enabled?
      t('two_factor_authentication.two_factor_aal3_choice')
    else
      t('two_factor_authentication.two_factor_choice')
    end
  end

  def intro
    if piv_cac_only_required?
      t('two_factor_authentication.two_factor_hspd12_choice_intro')
    elsif aal3_only?
      t('two_factor_authentication.two_factor_aal3_choice_intro')
    else
      t('two_factor_authentication.two_factor_choice_intro')
    end
  end

  def show_security_level?
    !(piv_cac_only_required? || (aal3_only? && mfa_policy.two_factor_enabled?))
  end

  private

  def piv_cac_option
    return [] unless current_device_is_desktop?
    [TwoFactorAuthentication::PivCacSelectionPresenter.new]
  end

  def webauthn_option
    return [] if piv_cac_only_required?
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new]
  end

  def phone_options
    return [] if piv_cac_only_required? || aal3_only? || FeatureManagement.hide_phone_mfa_signup?
    [TwoFactorAuthentication::PhoneSelectionPresenter.new]
  end

  def totp_option
    return [] if piv_cac_only_required? || aal3_only?
    [TwoFactorAuthentication::AuthAppSelectionPresenter.new]
  end

  def backup_code_option
    return [] if piv_cac_only_required? || aal3_only?
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
  end

  def current_device_is_desktop?
    DeviceDetector.new(@user_agent)&.device_type == 'desktop'
  end

  def piv_cac_only_required?
    @piv_cac_only_required
  end

  def aal3_only?
    @aal3_required && !mfa_policy.aal3_mfa_enabled?
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(@user)
  end
end
