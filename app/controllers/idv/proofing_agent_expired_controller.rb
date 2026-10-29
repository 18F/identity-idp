# frozen_string_literal: true

module Idv
  class ProofingAgentExpiredController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_proofing_agent_session_expired

    attr_reader :validity_hours

    def show
      analytics.idv_proofing_agent_expired_visited
      @validity_hours = agent_proofed_validity_hours
      render :show
    end

    def update
      analytics.idv_proofing_agent_expired_continued
      current_user.document_capture_sessions
        .where(doc_auth_vendor: Idp::Constants::Vendors::PROOFING_AGENT)
        .destroy_all

      redirect_to idv_welcome_path
    end

    private

    def confirm_proofing_agent_session_expired
      redirect_to account_path unless current_user&.agent_proofing_expired?
    end

    def agent_proofed_validity_hours
      IdentityConfig.store.agent_proofed_user_time_validity_hours
    end
  end
end
