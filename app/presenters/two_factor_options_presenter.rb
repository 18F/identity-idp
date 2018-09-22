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
    phone_options + totp_option + webauthn_option + piv_cac_option
  end

  private

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
    if TwoFactorAuthentication::WebauthnPolicy.new(current_user, service_provider).available?
      [TwoFactorAuthentication::WebauthnSelectionPresenter.new]
    else
      []
    end
  end

  def totp_option
    if TwoFactorAuthentication::AuthAppPolicy.new(current_user).available?
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
end
