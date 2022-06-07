module TwoFactorAuthentication
  class WebauthnPlatformSelectionPresenter < SelectionPresenter
    def method
      :webauthn_platform
    end

    def html_class
      'display-none'
    end

    def disabled?
      user&.webauthn_configurations&.where(platform_authenticator: true)&.any?
    end

    def mfa_configuration_count
      user.webauthn_configurations.where(platform_authenticator: true).count
    end
  end
end
