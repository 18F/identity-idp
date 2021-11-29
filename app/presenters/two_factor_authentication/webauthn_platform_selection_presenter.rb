module TwoFactorAuthentication
  class WebauthnPlatformSelectionPresenter < SelectionPresenter
    def method
      :webauthn_platform
    end

    def html_class
      'display-none'
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.more_secure_label')
    end
  end
end
