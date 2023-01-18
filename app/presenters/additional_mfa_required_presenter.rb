class AdditionalMfaRequiredPresenter
  attr_reader :current_user
  def initialize(current_user:)
    @current_user = current_user
  end

  def title
    if current_date > enforcement_date
      I18n.t('mfa.additional_mfa_required.heading')
    else
      I18n.t(
        'mfa.additional_mfa_required.title',
        date: I18n.l(enforcement_date, format: :event_date),
      )
    end
  end

  def button
    I18n.t('mfa.additional_mfa_required.button')
  end

  def info
    if current_date > enforcement_date
      I18n.t('mfa.additional_mfa_required.non_restricted_required_info')
    else
      I18n.t(
        'mfa.additional_mfa_required.info',
        date: I18n.l(enforcement_date, format: :event_date),
      )
    end
  end

  def skip
    if current_date > enforcement_date
      I18n.t('mfa.skip_once')
    else
      I18n.t('mfa.skip')
    end
  end

  def learn_more_text
    I18n.t('mfa.additional_mfa_required.learn_more')
  end

  def cant_skip_anymore?
    return false if current_date < enforcement_date
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

  private

  def current_date
    @current_date ||= Time.zone.today
  end

  def enforcement_date
    @enforcement_date ||= IdentityConfig.store.kantara_restriction_enforcement_date
  end
end
