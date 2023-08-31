class MfaConfirmationPresenter
  def initialize(show_skip_additional_mfa_link: true)
    @show_skip_additional_mfa_link = show_skip_additional_mfa_link
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

  def show_skip_additional_mfa_link?
    @show_skip_additional_mfa_link
  end
end
