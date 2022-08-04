module AccountReset
    class RecoveryOptionsController < ApplicationController
      include TwoFactorAuthenticatable
  
      before_action :confirm_two_factor_enabled
  
      def show
        analytics.account_reset_recovery_options_visit
      end

      def cancel
        # Want to do this so we can track properly
      end
  
      private

    end
  end
  