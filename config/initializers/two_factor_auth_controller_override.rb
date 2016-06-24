# Currently, the two_factor_authentication gem is designed to enforce the 2FA requirement in all
# controllers except Devise. However, the controller action for SLO needs to also be excluded.

module TwoFactorAuthentication
  module Controllers
    module Helpers
      private

      def handle_two_factor_authentication
        # Skip handling if devise, if the user is attempting to log out
        return if devise_controller? || requesting_log_out?

        Devise.mappings.keys.flatten.any? do |scope|
          if signed_in?(scope) &&
             warden.session(scope)[TwoFactorAuthentication::NEED_AUTHENTICATION]
            handle_failed_second_factor(scope)
          end
        end
      end

      def requesting_log_out?
        request.fullpath == destroy_user_session_path
      end
    end
  end
end
