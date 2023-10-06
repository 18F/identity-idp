module TwoFactorAuthentication
  class SetUpAuthAppSelectionPresenter < SetUpSelectionPresenter
    def method
      :auth_app
    end

    def mfa_configuration_count
      user.auth_app_configurations.count
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.auth_app')
    end

    def info
      t('two_factor_authentication.two_factor_choice_options.auth_app_info')
    end
  end
end
