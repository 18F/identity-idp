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
      before_action :validate_required_headers

      def search_user
        analytics.proofing_agent_request(
          issuer: request_token.issuer,
          success: true,
        )

        render json: { request_id: request.headers['X-Request-Id'] }
      end

      def proof_user
        analytics.proofing_agent_request(
          issuer: request_token.issuer,
          success: true,
        )

        render json: { request_id: request.headers['X-Request-Id'] }
      end

      private

      def validate_required_headers
        if request.headers['X-Proofing-Location-Id'].blank? ||
           request.headers['X-Agent-Id'].blank? ||
           request.headers['X-Request-Id'].blank?
          render json: {
            error: 'Missing required headers: X-Proofing-Location-Id, X-Agent-Id, X-Request-Id',
          }, status: :bad_request
        end
      end

      def authenticate_client
        if request_token.invalid?
          track_failure
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
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
