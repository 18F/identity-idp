# frozen_string_literal: true

module Idv
  # NDS dead end: identity verification currently needs a U.S. phone number,
  # so a user who enters a non-U.S. number on hybrid handoff lands here before
  # investing in document capture.
  class PhoneRequiredController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_nds_phone_first_handoff

    def show
      analytics.idv_phone_required_visited
    end

    private

    # Only the NDS phone-first flow sends users here, from hybrid handoff.
    # Anyone else (legacy or opted-out users, or users who can't be on hybrid
    # handoff) goes back to their current IdV step.
    def confirm_nds_phone_first_handoff
      return if nds_layout? &&
                idv_session.phone_first_flow? &&
                flow_policy.controller_allowed?(controller: Idv::HybridHandoffController)

      redirect_to url_for_latest_step
    end
  end
end
