class MfaConfirmationPresenter
  def initialize(user)
    @user = user
  end

  def enforce_second_mfa?
    IdentityConfig.store.select_multiple_mfa_options &&
      MfaContext.new(@user).enabled_non_restricted_mfa_methods_count < 1
  end

  def heading
    enforce_second_mfa? ?
      I18n.t('mfa.non_restricted.heading') :
      I18n.t('titles.mfa_setup.suggest_second_mfa')
  end

  def info
    enforce_second_mfa? ? I18n.t(
      'mfa.non_restricted.info',
    ) : I18n.t('mfa.account_info')
  end

  def button
    enforce_second_mfa? ? I18n.t('mfa.non_restricted.button') : I18n.t('mfa.add')
  end

  def learn_more
    MarketingSite.help_center_article_url(
      category: 'get-started',
      article: 'authentication-options',
    )
  end
end
