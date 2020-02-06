module TwoFactorAuthentication
  class AuthAppSelectionPresenter < SelectionPresenter
    def method
      :auth_app
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.secure_label')
    end
  end
end
