class MfaConfirmationPresenter
  def initialize(show_skip_additional_mfa_link: true, webauthn_platform_set_up_successful: false)
    @show_skip_additional_mfa_link = show_skip_additional_mfa_link
    @webauthn_platform_set_up_successful = webauthn_platform_set_up_successful
  end

  def heading
    if @webauthn_platform_set_up_successful
      I18n.t('titles.mfa_setup.face_touch_unlock_confirmation')
    else
      I18n.t('titles.mfa_setup.suggest_second_mfa')
    end
  end

  def info
    if @webauthn_platform_set_up_successful
      I18n.t('mfa.webauthn_platform_info')
    else
      I18n.t('mfa.account_info')
    end
  end

  def button
    I18n.t('mfa.add')
  end

  def show_skip_additional_mfa_link?
    @show_skip_additional_mfa_link
  end

  def webauthn_platform_set_up_successful?
    @webauthn_platform_set_up_successful
  end
end
