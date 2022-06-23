module TwoFactorAuthentication
  class PivCacSelectionPresenter < SelectionPresenter
    def method
      :piv_cac
    end

    def disabled?
      user&.piv_cac_configurations&.any?
    end

    def mfa_configuration_count
      user.piv_cac_configurations.count
    end
  end
end
