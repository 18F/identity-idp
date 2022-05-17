module TwoFactorAuthentication
  class PivCacSelectionPresenter < SelectionPresenter
    def method
      :piv_cac
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.more_secure_label')
    end

    def disabled?
      user&.piv_cac_configurations&.any?
    end

    def mfa_configuration_count
      user.piv_cac_configurations.count
    end
  end
end
