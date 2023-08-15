module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def method
      :backup_code
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user&.backup_code_configurations&.unused&.count || 0
    end
  end
end
