module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def initialize(user)
      @user = user
    end

    def method
      if MfaPolicy.new(@user).no_factors_enabled?
        :backup_code_only
      else
        :backup_code
      end
    end
  end
end
