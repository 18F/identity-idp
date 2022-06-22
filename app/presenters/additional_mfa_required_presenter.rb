class AdditionalMfaRequiredPresenter 
    def title
      I18n.t(
        'mfa.additional_mfa_required.title', 
        date: enforcement_date)
    end
  
    def button
      I18n.t('mfa.additional_mfa_required.button')
    end

    def info
      I18n.t('mfa.additional_mfa_required.info', date: enforcement_date)
    end

    def skip
      I18n.t('mfa.skip')
    end
    
    def learn_more_text
      I18n.t('mfa.additional_mfa_required.learn_more')
    end

    def cant_skip_anymore?
      return false if Date.now < enforcement_date
    end

    def learn_more_link
      MarketingSite.help_center_article_url(
        category: 'get-started',
        article: 'authentication-options',
      )
    end

    def enforcement_date
      @date ||= IdentityConfig.store.kantara_restriction_enforcement_date
      @date.to_s(:long_ordinal)
    end
  end
  