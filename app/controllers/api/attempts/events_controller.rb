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
      before_action :validate_params, only: :poll

      def poll
        deleted_events_count = 0
        if poll_params[:ack].present?
          deleted_events_count = redis_client.delete_events(
            issuer: request_token.issuer,
            keys: poll_params[:ack],
          )
        end

        sets = redis_client.read_events(
          issuer: request_token.issuer,
          batch_size: batch_size,
        )

        analytics.attempts_api_poll_events_request(
          issuer: request_token.issuer,
          requested_events_count: batch_size,
          requested_acknowledged_events_count: poll_params[:ack]&.length,
          returned_events_count: sets.count,
          acknowledged_events_count: deleted_events_count,
          success: true,
        )

        render json: { sets: }
      end

      def status
        render json: {
          status: :disabled,
          reason: :not_yet_implemented,
        }
      end

      private

      def authenticate_client
        if request_token.invalid?
          track_failure
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def poll_params
        params.permit(:maxEvents, ack: [])
      end

      def batch_size
        poll_params[:maxEvents]&.to_i || event_limit
      end

      def redis_client
        @redis_client ||= AttemptsApi::RedisClient.new
      end

      def request_token
        @request_token ||= AttemptsApi::RequestTokenValidator.new(request.authorization)
      end

      def validate_params
        if poll_params[:maxEvents].present? && !poll_params[:maxEvents].to_i.between?(
          1,
          event_limit,
        )
          track_failure
          render json: { error: 'maxEvents must be between 1 and 1000' },
                 status: :bad_request
        end
      end

      def track_failure
        analytics.attempts_api_poll_events_request(
          issuer: request_token&.issuer,
          requested_events_count: nil,
          requested_acknowledged_events_count: nil,
          returned_events_count: nil,
          acknowledged_events_count: nil,
          success: false,
        )
      end

      def event_limit
        1000
      end
    end
  end
end
