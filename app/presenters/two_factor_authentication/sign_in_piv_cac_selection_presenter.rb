module TwoFactorAuthentication
  class SignInPivCacSelectionPresenter < SignInSelectionPresenter
    def method
      :piv_cac
    end

    def label
      t('two_factor_authentication.login_options.piv_cac')
    end

    def info
      t('two_factor_authentication.login_options.piv_cac_info')
    end
  end
end
