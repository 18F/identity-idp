class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :after_mfa_setup_path, :return_to_sp_cancel_path

  delegate :two_factor_enabled?, to: :mfa_policy

  def initialize(
    user_agent:,
    user: nil,
    phishing_resistant_required: false,
    piv_cac_required: false,
    show_skip_additional_mfa_link: true,
    after_mfa_setup_path: nil,
    return_to_sp_cancel_path: nil
  )
    @user_agent = user_agent
    @user = user
    @phishing_resistant_required = phishing_resistant_required
    @piv_cac_required = piv_cac_required
    @show_skip_additional_mfa_link = show_skip_additional_mfa_link
    @after_mfa_setup_path = after_mfa_setup_path
    @return_to_sp_cancel_path = return_to_sp_cancel_path
  end

  def options
    all_options_sorted.select { |option| show_option?(option) }
  end

  def all_options_sorted
    [
      TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter.new(user:),
      TwoFactorAuthentication::SetUpAuthAppSelectionPresenter.new(user:),
      TwoFactorAuthentication::SetUpPhoneSelectionPresenter.new(user:),
      TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter.new(user:),
      TwoFactorAuthentication::SetUpWebauthnSelectionPresenter.new(user:),
      TwoFactorAuthentication::SetUpPivCacSelectionPresenter.new(user:),
    ].partition(&:recommended?).flatten
  end

  def icon
    if piv_cac_required? || (phishing_resistant_only? && mfa_policy.two_factor_enabled?)
      'icon-lock-alert-important.svg'
    end
  end

  def icon_alt_text
    t('two_factor_authentication.important_alert_icon')
  end

  def heading
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice')
    elsif phishing_resistant_only? && mfa_policy.two_factor_enabled?
      t('two_factor_authentication.two_factor_aal3_choice')
    else
      t('two_factor_authentication.two_factor_choice')
    end
  end

  def intro
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice_intro')
    elsif phishing_resistant_only?
      t('two_factor_authentication.two_factor_aal3_choice_intro')
    else
      t('mfa.info', app_name: APP_NAME)
    end
  end

  def show_cancel_return_to_sp?
    phishing_resistant_only? || piv_cac_required?
  end

  def show_skip_additional_mfa_link?
    @show_skip_additional_mfa_link
  end

  def skip_path
    if show_cancel_return_to_sp?
      return_to_sp_cancel_path
    elsif two_factor_enabled? && show_skip_additional_mfa_link?
      after_mfa_setup_path
    end
  end

  def skip_label
    if user_has_dismissed_second_mfa_reminder? || show_cancel_return_to_sp?
      t('links.cancel')
    else
      t('mfa.skip')
    end
  end

  private

  def show_option?(option)
    case option
    when TwoFactorAuthentication::SetUpPivCacSelectionPresenter
      current_device_is_desktop?
    when TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
         TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter
      !piv_cac_required?
    when TwoFactorAuthentication::SetUpPhoneSelectionPresenter
      !piv_cac_required? && !phishing_resistant_only? && !IdentityConfig.store.hide_phone_mfa_signup
    when TwoFactorAuthentication::SetUpAuthAppSelectionPresenter,
         TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter
      !piv_cac_required? && !phishing_resistant_only?
    end
  end

  def current_device_is_desktop?
    !BrowserCache.parse(@user_agent).mobile?
  end

  def piv_cac_required?
    @piv_cac_required
  end

  def phishing_resistant_only?
    @phishing_resistant_required && !mfa_policy.phishing_resistant_mfa_enabled?
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(user)
  end

  def user_has_dismissed_second_mfa_reminder?
    user.second_mfa_reminder_dismissed_at.present?
  end
end
