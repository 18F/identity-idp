class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :service_provider

  def initialize(current_user, sp, user_agent)
    @current_user = current_user
    @service_provider = sp
    @is_desktop = DeviceDetector.new(user_agent)&.device_type == 'desktop'
  end

  # i18n-tasks-use t('titles.two_factor_setup')
  # i18n-tasks-use t('titles.two_factor_recovery_setup')
  def title
    t("titles.two_factor_#{recovery}setup")
  end

  # i18n-tasks-use t('two_factor_authentication.two_factor_choice')
  # i18n-tasks-use t('two_factor_authentication.two_factor_recovery_choice')
  def heading
    t("two_factor_authentication.two_factor_#{recovery}choice")
  end

  # i18n-tasks-use t('two_factor_authentication.two_factor_choice_intro_paragraphs')
  # i18n-tasks-use t('two_factor_authentication.two_factor_recovery_choice_intro_paragraphs')
  def intro_parapraphs
    t("two_factor_authentication.two_factor_#{recovery}choice_intro_paragraphs")
  end

  # i18n-tasks-use t('forms.two_factor_choice.legend')
  # i18n-tasks-use t('forms.two_factor_recovery_choice.legend')
  def label
    t("forms.two_factor_#{recovery}choice.legend") + ':'
  end

  def options
    totp_option + webauthn_option + phone_options + piv_cac_option + backup_code_option
  end

  def no_factors_enabled?
    MfaPolicy.new(current_user).no_factors_enabled?
  end

  private

  def recovery
    no_factors_enabled? ? '' : 'recovery_'
  end

  def phone_options
    return [] if FeatureManagement.hide_phone_mfa_signup?

    if TwoFactorAuthentication::PhonePolicy.new(current_user).second_phone?
      [
        TwoFactorAuthentication::SecondPhoneSelectionPresenter.new(
          current_user.phone_configurations.take,
        ),
      ]
    else
      [TwoFactorAuthentication::PhoneSelectionPresenter.new]
    end
  end

  def webauthn_option
    if TwoFactorAuthentication::WebauthnPolicy.new(current_user).available?
      [TwoFactorAuthentication::WebauthnSelectionPresenter.new]
    else
      []
    end
  end

  def totp_option
    [TwoFactorAuthentication::AuthAppSelectionPresenter.new]
  end

  def piv_cac_option
    return [] unless @is_desktop
    [TwoFactorAuthentication::PivCacSelectionPresenter.new]
  end

  def backup_code_option
    if TwoFactorAuthentication::BackupCodePolicy.new(current_user).enrollable?
      [TwoFactorAuthentication::BackupCodeSelectionPresenter.new(current_user)]
    else
      []
    end
  end
end
