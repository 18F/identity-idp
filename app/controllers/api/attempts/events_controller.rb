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
        bearer, issuer, token = request.authorization&.split(' ', 3)
        if bearer != 'Bearer' ||
           config_data(issuer).blank? || !valid_auth_token?(token, issuer)

          render json: { status: 401, description: 'Unauthorized' }, status: :unauthorized
        end
      end

      def service_provider(issuer)
        !IdentityConfig.store.allowed_attempts_providers.map(&:issuer).include?(issuer)
      end

      def valid_auth_token?(token, issuer)
        config_data(issuer)[:token] == token
      end

      def poll_params
        params.permit(:maxEvents, acks: [])
      end

      def config_data(issuer)
        IdentityConfig.store.allowed_attempts_providers.find do |config|
          config[:issuer] == issuer
        end
      end
    end
  end
end
