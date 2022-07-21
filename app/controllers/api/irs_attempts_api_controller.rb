##
# This controller implements the Poll-based delivery method for Security Event
# Tokens as described RFC 8936
#
# ref: https://datatracker.ietf.org/doc/html/rfc8936
#
module Api
  class IrsAttemptsApiController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :render_404_if_disabled
    before_action :authenticate_client

    respond_to :json

    def create
      acknowledge_acked_events
      render json: { sets: security_event_tokens }
      analytics.irs_attempts_api_events(**analytics_properties)
    end

    private

    def render_404_if_disabled
      render_not_found unless IdentityConfig.store.irs_attempt_api_enabled
    end

    def authenticate_client
      bearer, token = request.authorization.split(' ', 2)
      if bearer != 'Bearer' || !valid_auth_tokens.include?(token)
        render json: { status: 401, description: 'Unauthorized' }, status: :unauthorized
      end
    end

    def acknowledge_acked_events
      redis_client.delete_events(ack_event_ids)
    end

    def ack_event_ids
      params['ack'] || []
    end

    def requested_event_count
      count = if params['maxEvents']
                params['maxEvents'].to_i
              else
                IdentityConfig.store.irs_attempt_api_event_count_default
              end

      [count, IdentityConfig.store.irs_attempt_api_event_count_max].min
    end

    def security_event_tokens
      @security_event_tokens ||= redis_client.read_events(requested_event_count)
    end

    def security_event_token_errors
      return unless params['setErrs'].present?
      params['setErrs'].to_json
    end

    def redis_client
      @redis_client ||= IrsAttemptsApi::RedisClient.new
    end

    def valid_auth_tokens
      IdentityConfig.store.irs_attempt_api_auth_tokens
    end

    def analytics_properties
      {
        acknowledged_event_count: ack_event_ids.count,
        rendered_event_count: security_event_tokens.keys.count,
        set_errors: security_event_token_errors,
      }
    end
  end
end
