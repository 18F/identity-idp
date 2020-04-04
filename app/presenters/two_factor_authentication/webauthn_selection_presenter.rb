module TwoFactorAuthentication
  class WebauthnSelectionPresenter < SelectionPresenter
    def method
      :webauthn
    end

    def html_class
      'hide'
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.secure_label')
    end
  end
end
