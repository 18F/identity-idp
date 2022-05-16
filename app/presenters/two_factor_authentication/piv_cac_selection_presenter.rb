module TwoFactorAuthentication
  class PivCacSelectionPresenter < SelectionPresenter
    def method
      :piv_cac
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.more_secure_label')
    end

    def disabled?
      !user.nil? && user.piv_cac_configurations.any?
    end

    def mfa_configuration
      return '' if !disabled?
      text = user.piv_cac_configurations.count == 1 ?
        'two_factor_authentication.two_factor_choice_options.configurations_added' :
        'two_factor_authentication.two_factor_choice_options.configurations_added_plural'
      return t(
        text,
        count: user.piv_cac_configurations.count,
      )
    end
  end
end
