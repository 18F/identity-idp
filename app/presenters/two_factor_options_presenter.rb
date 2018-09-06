class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :service_provider

  def initialize(current_user, sp)
    @current_user = current_user
    @service_provider = sp
  end

  def title
    t('titles.two_factor_setup')
  end

  def heading
    t('two_factor_authentication.two_factor_choice')
  end

  def info
    t('two_factor_authentication.two_factor_choice_intro')
  end

  def label
    t('forms.two_factor_choice.legend') + ':'
  end

  def options
    phone_options + totp_option + webauthn_option + piv_cac_option_if_available
  end

  private

  def phone_options
    if current_user.mfa.phone_configurations.any?(&:mfa_enabled?)
      []
    else
      [
        TwoFactorAuthentication::SmsSelectionPresenter.new,
        TwoFactorAuthentication::VoiceSelectionPresenter.new,
      ]
    end
  end

  def webauthn_option
    if current_user.mfa.webauthn_configurations.any?(&:mfa_enabled?)
      []
    elsif FeatureManagement.webauthn_enabled?
      [TwoFactorAuthentication::WebauthnSelectionPresenter.new]
    end
  end

  def totp_option
    if current_user.mfa.auth_app_configuration.mfa_enabled?
      []
    else
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new]
    end
  end

  def piv_cac_option_if_available
    configuration = current_user.mfa.piv_cac_configuration
    return [] if configuration.mfa_enabled?
    return [] unless configuration.mfa_available? ||
                     service_provider&.piv_cac_available?(current_user)
    [TwoFactorAuthentication::PivCacSelectionPresenter.new]
  end
end
