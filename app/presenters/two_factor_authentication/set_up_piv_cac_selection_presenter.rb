module TwoFactorAuthentication
  class SetUpPivCacSelectionPresenter < SetUpSelectionPresenter
    def type
      :piv_cac
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.piv_cac')
    end

    def info
      t('two_factor_authentication.two_factor_choice_options.piv_cac_info')
    end

    def recommended?
      user.confirmed_email_addresses.any?(&:gov_or_mil?)
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user.piv_cac_configurations.count
    end
  end
end
