# frozen_string_literal: true

module Idv
  module ProofingAgentConcern
    private

    def proofing_agent_analytics
      return {} unless agent_proofed_user

      {
        proofing_agent: {
          agent_id: agent_proofed_user.proofing_agent_id,
          location_id: agent_proofed_user.proofing_location_id,
          correlation_id: agent_proofed_user.correlation_id,
          transaction_id: agent_proofed_user.transaction_id,
        },
        issuer:,
      }
    end

    def issuer
      agent_proofed_user.issuer || current_user.pending_agent_proofed_session.issuer
    end

    def agent_proofed_user
      @agent_proofed_user ||= current_user&.pending_agent_proofed_user
    end
  end
end
