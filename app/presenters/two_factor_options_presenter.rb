class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :service_provider

  def initialize(current_user, sp)
    @current_user = current_user
    @service_provider = sp
  end

  def title
    t("titles.two_factor_#{recovery}setup")
  end

  def heading
    t("two_factor_authentication.two_factor_#{recovery}choice")
  end

  def info
    t("two_factor_authentication.two_factor_#{recovery}choice_intro")
  end

  def label
    t("forms.two_factor_#{recovery}choice.legend") + ':'
  end

  def options
    phone_options + totp_option + webauthn_option + piv_cac_option + backup_code_option
  end

  def no_factors_enabled?
    MfaPolicy.new(current_user).no_factors_enabled?
  end

  def first_mfa_successfully_enabled_message
    t('two_factor_authentication.first_factor_enabled', device: first_mfa_enabled)
  end

  private

  def first_mfa_enabled
    t("two_factor_authentication.devices.#{FirstMfaEnabledForUser.call(current_user)}")
  end

  def recovery
    no_factors_enabled? ? '' : 'recovery_'
  end

  def phone_options
    if TwoFactorAuthentication::PhonePolicy.new(current_user).available?
      [
        TwoFactorAuthentication::SmsSelectionPresenter.new,
        TwoFactorAuthentication::VoiceSelectionPresenter.new,
      ]
    else
      []
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
    if TwoFactorAuthentication::AuthAppPolicy.new(current_user).enrollable?
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new]
    else
      []
    end
  end

  def piv_cac_option
    policy = TwoFactorAuthentication::PivCacPolicy.new(current_user)
    return [] if policy.enabled?
    return [] unless policy.available? || service_provider&.piv_cac_available?(current_user)
    [TwoFactorAuthentication::PivCacSelectionPresenter.new]
  end

  def backup_code_option
    if TwoFactorAuthentication::BackupCodePolicy.new(current_user).enrollable?
      [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
    else
      []
    end
  end
end
