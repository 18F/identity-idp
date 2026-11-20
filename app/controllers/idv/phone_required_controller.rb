# frozen_string_literal: true

module Idv
  class PhoneRequiredController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_nds_phone_first_handoff

    def show
      analytics.idv_phone_required_visited
    end

    private

    def confirm_nds_phone_first_handoff
      handoff_allowed = idv_session.phone_first_flow? &&
                        flow_policy.controller_allowed?(controller: Idv::HybridHandoffController)
      return if handoff_allowed && nds_layout?

      redirect_to handoff_allowed ? idv_hybrid_handoff_url : url_for_latest_step
    end
  end
end
