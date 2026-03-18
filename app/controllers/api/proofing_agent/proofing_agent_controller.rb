# frozen_string_literal: true

module Api
  module ProofingAgent
    class ProofingAgentController < ApplicationController
      include RenderConditionConcern

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration
      skip_before_action :verify_authenticity_token

      check_or_render_not_found -> { FeatureManagement.idv_proofing_agent_enabled? }

      before_action :validate_required_headers

      def search_user
        render json: { request_id: SecureRandom.uuid }
      end

      def proof_user
        render json: { request_id: SecureRandom.uuid }
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
    end
  end
end
