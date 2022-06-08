module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def method
      :backup_code
    end

    def disabled?
      user&.backup_code_configurations&.any?
    end

    def mfa_configuration_description
      return '' if !disabled?
      t(
        'two_factor_authentication.two_factor_choice_options.unused_backup_code',
        count: mfa_configuration_count,
      )
    end

    def mfa_configuration_count
      user.backup_code_configurations.unused.count
    end
  end
end
