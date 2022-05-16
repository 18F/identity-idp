module TwoFactorAuthentication
  class AuthAppSelectionPresenter < SelectionPresenter
    def method
      :auth_app
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.secure_label')
    end

    def disabled?
      !user.nil? && user.auth_app_configurations.any?
    end

    def mfa_configuration
      return '' if !disabled?
      text = user.auth_app_configurations.count == 1 ?
        'two_factor_authentication.two_factor_choice_options.configurations_added' :
        'two_factor_authentication.two_factor_choice_options.configurations_added_plural'
      return t(
        text,
        count: user.auth_app_configurations.count,
      )
    end
  end
end
