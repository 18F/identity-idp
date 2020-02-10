module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    def initialize(user)
      @user = user
      super(user&.backup_code_configurations&.take)
    end

    def method
      if MfaPolicy.new(@user).no_factors_enabled?
        :backup_code_only
      else
        :backup_code
      end
    end

    # :reek:UtilityFunction
    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.less_secure_label')
    end
  end
end
