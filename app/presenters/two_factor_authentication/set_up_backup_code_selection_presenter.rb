# frozen_string_literal: true

module TwoFactorAuthentication
  class SetUpBackupCodeSelectionPresenter < SetUpSelectionPresenter
    def type
      :backup_code
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.backup_code')
    end

    def info
      t(
        'two_factor_authentication.two_factor_choice_options.backup_code_info',
        count: ReadableNumber.of(BackupCodeGenerator::NUMBER_OF_CODES),
      )
    end

    def phishing_resistant?
      false
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user.backup_code_configurations.unused.count
    end
  end
end
