module AccountReset
    class RecoveryOptionsController < ApplicationController
      include TwoFactorAuthenticatable
  
      before_action :confirm_two_factor_enabled
  
      def show
        recovery_options_visit
        
      end

      def cancel
        # Want to do this so we can track properly
      end
  
      private

      def confirm_two_factor_enabled
        return if MfaPolicy.new(current_user).two_factor_enabled?
      end

      def recovery_options_visit
        analytics.account_reset_recovery_options_visit
      end

    end
  end
  