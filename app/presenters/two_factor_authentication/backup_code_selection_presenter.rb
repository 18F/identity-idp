module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def method
      :backup_code
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.least_secure_label')
    end

    def disabled?
      !user.nil? && user.backup_code_configurations.any?
    end

    def mfa_configuration
      return '' if !disabled?
      text = user.backup_code_configurations.unused.count == 1 ?
        'two_factor_authentication.two_factor_choice_options.unused_backup_code' :
        'two_factor_authentication.two_factor_choice_options.unused_backup_code_plural'
      return t(
        text,
        count: user.backup_code_configurations.unused.count,
      )
    end
  end
end
