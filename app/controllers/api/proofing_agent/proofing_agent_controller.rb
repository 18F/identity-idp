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
        render json: { request_id: }
      end

      def proof_user
        render json: { request_id: }
      end

      private

      def validate_required_headers
        if location_id.blank? || agent_id.blank? || request_id.blank?
          track_failure(failure_type: :validation, agent_id:, location_id:, request_id:)

          render json: {
            error: 'Missing required headers: X-Proofing-Location-Id, X-Agent-Id, X-Request-Id',
          }, status: :bad_request
        end
      end

      def authenticate_client
        if request_token.invalid?
          track_failure(failure_type: :authorization)
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def agent_id
        @agent_id ||= request.headers['X-Agent-Id']
      end

      def location_id
        @location_id ||= request.headers['X-Proofing-Location-Id']
      end

      def request_id
        @request_id ||= request.headers['X-Request-ID']
      end

      def request_token
        @request_token ||= ::ProofingAgent::RequestTokenValidator.new(request.authorization)
      end

      def track_failure(failure_type:, agent_id: nil, location_id: nil, request_id: nil)
        analytics.idv_proofing_agent_request_failed(
          issuer: request_token&.issuer,
          success: false,
          failure_type:,
          agent_id:,
          location_id:,
          request_id:,
        )
      end
    end
  end
end
