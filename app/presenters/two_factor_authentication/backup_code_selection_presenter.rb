module TwoFactorAuthentication
  class BackupCodeSelectionPresenter < SelectionPresenter
    # :reek:BooleanParameter
    def initialize(only = false)
      @only_backup_codes = only
    end

    def method
      if @only_backup_codes
        :backup_code_only
      else
        :backup_code
      end
    end

    private

    attr_reader :only_backup_codes
  end
end
