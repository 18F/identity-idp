class MfaConfirmationPresenter
  def initialize(user)
    @user = user
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
end
