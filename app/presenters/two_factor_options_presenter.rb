# frozen_string_literal: true

class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user,
              :after_mfa_setup_path,
              :return_to_sp_cancel_path,
              :phishing_resistant_required,
              :piv_cac_required,
              :user_agent,
              :desktop_ft_ab_test

  delegate :two_factor_enabled?, to: :mfa_policy
  def initialize(
    user_agent:,
    user: nil,
    phishing_resistant_required: false,
    piv_cac_required: false,
    show_skip_additional_mfa_link: true,
    after_mfa_setup_path: nil,
    return_to_sp_cancel_path: nil,
    desktop_ft_ab_test: nil
  )
    @user_agent = user_agent
    @user = user
    @phishing_resistant_required = phishing_resistant_required
    @piv_cac_required = piv_cac_required
    @show_skip_additional_mfa_link = show_skip_additional_mfa_link
    @after_mfa_setup_path = after_mfa_setup_path
    @return_to_sp_cancel_path = return_to_sp_cancel_path
    @desktop_ft_ab_test = desktop_ft_ab_test
  end

  def options
    all_options_sorted.select(&:visible?)
  end

  def all_options_sorted
    [
      TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter,
      TwoFactorAuthentication::SetUpAuthAppSelectionPresenter,
      TwoFactorAuthentication::SetUpPhoneSelectionPresenter,
      TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
      TwoFactorAuthentication::SetUpPivCacSelectionPresenter,
      TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter,
    ].map do |klass|
      klass.new(
        user:,
        piv_cac_required: piv_cac_required?,
        phishing_resistant_required: phishing_resistant_only?,
        user_agent:,
        desktop_ft_ab_test:,
      )
    end.
      partition(&:recommended?).
      flatten
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
    elsif show_skip_additional_mfa_link? && two_factor_enabled?
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

  def piv_cac_required?
    @piv_cac_required &&
      !mfa_policy.piv_cac_mfa_enabled?
  end

  def phishing_resistant_only?
    @phishing_resistant_required &&
      !mfa_policy.phishing_resistant_mfa_enabled?
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(user)
  end

  def user_has_dismissed_second_mfa_reminder?
    user.second_mfa_reminder_dismissed_at.present?
  end
end
