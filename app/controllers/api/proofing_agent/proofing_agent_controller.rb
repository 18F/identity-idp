# frozen_string_literal: true

module Api
  module ProofingAgent
    class ProofingAgentController < ApplicationController
      include RenderConditionConcern
      check_or_render_not_found -> { FeatureManagement.idv_proofing_agent_enabled? }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      skip_before_action :verify_authenticity_token
      before_action :authenticate_client

      def search_user
        analytics.proofing_agent_request(
          issuer: request_token.issuer,
          success: true,
          request_id:,
          request_type: :search_user,
        )

        render json: { request_id: }
      end

      def proof_user
        analytics.proofing_agent_request(
          issuer: request_token.issuer,
          success: true,
          request_id:,
          request_type: :proof_user,
        )

        render json: { request_id: }
      end

      private

      def authenticate_client
        if request_token.invalid?
          track_failure
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def request_id
        SecureRandom.uuid
      end

      def request_token
        @request_token ||= ::ProofingAgent::RequestTokenValidator.new(request.authorization)
      end

      def track_failure
        analytics.proofing_agent_request(
          issuer: request_token&.issuer,
          success: false,
        )
      end
    end
  end
end
