class AdditionalMfaRequiredPresenter
  attr_reader :current_user
  def initialize(current_user:)
    @current_user = current_user
  end

  def title
    I18n.t(
      'mfa.additional_mfa_required.title',
      date: enforcement_date.to_s(:long_ordinal),
    )
  end

  def button
    I18n.t('mfa.additional_mfa_required.button')
  end

  def info
    I18n.t('mfa.additional_mfa_required.info', date: enforcement_date.to_s(:long_ordinal))
  end

  def skip
    I18n.t('mfa.skip')
  end

  def learn_more_text
    I18n.t('mfa.additional_mfa_required.learn_more')
  end

  def cant_skip_anymore?
    return false if Time.zone.today < enforcement_date
    return false unless current_user.non_restricted_mfa_required_prompt_skip_date
    current_user.non_restricted_mfa_required_prompt_skip_date >
      enforcement_date
  end

  def learn_more_link
    MarketingSite.help_center_article_url(
      category: 'get-started',
      article: 'authentication-options',
    )
  end

  def enforcement_date
    @enforcement_date ||= IdentityConfig.store.kantara_restriction_enforcement_date
  end
  end
