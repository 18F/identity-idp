module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def method
      :backup_code
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.least_secure_label')
    end
  end
end
