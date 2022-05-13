module TwoFactorAuthentication
  class WebauthnPlatformSelectionPresenter < SelectionPresenter
    def method
      :webauthn_platform
    end

    def html_class
      'display-none'
    end

    def disabled?
      user.webauthn_configurations.where(platform_authenticator: true).any?
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.more_secure_label')
    end

    def mfa_configuration
      return '' if !disabled?
      t(
        'two_factor_authentication.two_factor_choice_options.configurations_added',
        count: user.webauthn_configurations.where(platform_authenticator: true).count,
      )
    end
  end
end
