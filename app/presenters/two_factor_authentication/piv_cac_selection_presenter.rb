module TwoFactorAuthentication
  class PivCacSelectionPresenter < SelectionPresenter
    def method
      :piv_cac
    end

    def disabled?
      user&.piv_cac_configurations&.any?
    end

    def mfa_configuration_description
      return '' if !disabled?
      t(
        'two_factor_authentication.two_factor_choice_options.no_count_configuration_added',
      )
    end

    def mfa_added_label
      ''
    end

    def mfa_configuration_count
      user.piv_cac_configurations.count
    end
  end
end
