module TwoFactorAuthentication
  class WebauthnSelectionPresenter < SelectionPresenter
    def method
      :webauthn
    end

    def html_class
      'display-none'
    end

    def disabled?
      user&.webauthn_configurations&.where(platform_authenticator: [false, nil])&.any?
    end

    def mfa_configuration_count
      user.webauthn_configurations.where(platform_authenticator: [false, nil]).count
    end
  end
end
