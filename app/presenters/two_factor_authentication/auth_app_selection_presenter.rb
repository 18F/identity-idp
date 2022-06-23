module TwoFactorAuthentication
  class AuthAppSelectionPresenter < SelectionPresenter
    def method
      :auth_app
    end

    def disabled?
      user&.auth_app_configurations&.any?
    end

    def mfa_configuration_count
      user.auth_app_configurations.count
    end
  end
end
