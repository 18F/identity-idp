module TwoFactorAuthentication
  class WebauthnSelectionPresenter < SelectionPresenter
    def method
      :webauthn
    end

    def html_class
      'display-none'
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.more_secure_label')
    end

    def disabled?
      !user.nil? && user.webauthn_configurations.where(platform_authenticator: [false, nil]).any?
    end

    def mfa_configuration
      return '' if !disabled?
      text = user.webauthn_configurations.where(platform_authenticator: [false, nil]).count == 1 ?
        'two_factor_authentication.two_factor_choice_options.configurations_added' :
        'two_factor_authentication.two_factor_choice_options.configurations_added_plural'
      return t(
        text,
        count: user.webauthn_configurations.where(platform_authenticator: [false, nil]).count,
      )
    end
  end
end
