# frozen_string_literal: true

module Idv
  class ProofingAgentExpiredController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_proofing_agent_session_expired

    def show
      analytics.idv_proofing_agent_expired_visited
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
  end
end
