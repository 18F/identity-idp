module TwoFactorAuthentication
  class SignInAuthAppSelectionPresenter < SignInSelectionPresenter
    def method
      :auth_app
    end

    def label
      t('two_factor_authentication.login_options.auth_app')
    end

    def info
      t('two_factor_authentication.login_options.auth_app_info')
    end
  end
end
