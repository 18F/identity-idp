module Idv
  module ByMail
    class LetterEnqueuedController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSessionConcern
      include Idv::StepIndicatorConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_user_needs_gpo_confirmation

      def show
        analytics.idv_letter_enqueued_visit
        @pii = {
          address1: "Address 1",
          address2: "Address 2",
          city: "City",
          state: "ST",
          zipcode: "99999",
        }
      end

      private

      def confirm_user_needs_gpo_confirmation
        redirect_to account_url unless current_user.gpo_verification_pending_profile?
      end
    end
  end
end
