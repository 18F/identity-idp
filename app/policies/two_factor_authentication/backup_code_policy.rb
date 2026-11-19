# frozen_string_literal: true

module TwoFactorAuthentication
  class BackupCodePolicy
    def initialize(user)
      @user = user
    end

    def configured?
      @user.backup_code_configurations.available_for_authentication.unused.any?
    end

    private

    attr_reader :user
  end
end
