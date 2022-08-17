module AccountReset
  class RecoveryOptionsController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled

    def show
      recovery_options_visit
    end

    def cancel
      cancel_account_reset_recovery_options
      redirect_to login_two_factor_options_url
    end

    private

    def confirm_two_factor_enabled
      return if MfaPolicy.new(current_user).two_factor_enabled?
      redirect_to login_two_factor_options_path
    end

    def recovery_options_visit
      analytics.account_reset_recovery_options_visit
    end

    def cancel_account_reset_recovery_options
      analytics.cancel_account_reset_recovery
    end
  end
end
