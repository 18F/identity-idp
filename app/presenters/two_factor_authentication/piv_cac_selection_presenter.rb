module TwoFactorAuthentication
  class PivCacSelectionPresenter < SelectionPresenter
    def method
      :piv_cac
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user&.piv_cac_configurations&.count || 0
    end
  end
end
