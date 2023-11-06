module TwoFactorAuthentication
  class SignInBackupCodeSelectionPresenter < SignInSelectionPresenter
    def method
      :backup_code
    end

    def label
      t('two_factor_authentication.login_options.backup_code')
    end

    def info
      t('two_factor_authentication.login_options.backup_code_info')
    end
  end
end
