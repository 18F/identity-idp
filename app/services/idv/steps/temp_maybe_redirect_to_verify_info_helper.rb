# This module and calls to it can be removed when the in_person_verify_info_controller_enabled
# flag is removed.
#

module Idv
  module Steps
    module TempMaybeRedirectToVerifyInfoHelper
      private

      def maybe_redirect_to_verify_info
        return unless IdentityConfig.store.in_person_verify_info_controller_enabled
        flow_session[:flow_path] = @flow.flow_path
        redirect_to idv_in_person_verify_info_url
      end

      def redirect_to_address
        redirect_to idv_address_path
      end
    end
  end
end
