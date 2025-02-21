# frozen_string_literal: true

module Api
  module Attempts
    class EventsController < ApplicationController
      include RenderConditionConcern
      check_or_render_not_found -> { IdentityConfig.store.attempts_api_enabled }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      skip_before_action :verify_authenticity_token
      before_action :authenticate_client, only: :poll

      def poll
        head :method_not_allowed
      end

      def status
        render json: {
          status: :disabled,
          reason: :not_yet_implemented,
        }
      end

      private

      def authenticate_client
        if AttemptsApi::RequestTokenValidator.new(request.authorization).invalid?
          render json: { status: 401, description: 'Unauthorized' }, status: :unauthorized
        end
      end

      def poll_params
        params.permit(:maxEvents, acks: [])
      end
    end
  end
end
