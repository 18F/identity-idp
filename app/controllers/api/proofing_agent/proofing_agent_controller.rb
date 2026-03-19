# frozen_string_literal: true

module Api
  module ProofingAgent
    class ProofingAgentController < ApplicationController
      include RenderConditionConcern

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration
      skip_before_action :verify_authenticity_token

      check_or_render_not_found -> { FeatureManagement.idv_proofing_agent_enabled? }

      def search_user
        render json: { request_id: SecureRandom.uuid }
      end

      def proof_user
        render json: { request_id: SecureRandom.uuid }
      end
    end
  end
end
