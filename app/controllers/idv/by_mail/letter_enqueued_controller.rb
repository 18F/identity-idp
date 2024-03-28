# frozen_string_literal: true

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
        @presenter = LetterEnqueuedPresenter.new(
          idv_session:,
          user_session:,
          current_user:,
          url_options:,
        )
      end

      private

      def confirm_user_needs_gpo_confirmation
        redirect_to account_url unless current_user.gpo_verification_pending_profile?
      end
    end
  end
end
