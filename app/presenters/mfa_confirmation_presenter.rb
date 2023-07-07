class MfaConfirmationPresenter
  attr_reader :mfa_context

  def initialize(mfa_context)
    @mfa_context = mfa_context
  end

  def heading
    I18n.t('titles.mfa_setup.suggest_second_mfa')
  end

  def info
    I18n.t('mfa.account_info')
  end

  def button
    I18n.t('mfa.add')
  end

  def show_skip_link?
    !(mfa_context.enabled_mfa_methods_count == 1 &&
       mfa_context.webauthn_platform_configurations.count == 1)
  end
end
