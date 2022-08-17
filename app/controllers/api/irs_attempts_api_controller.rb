##
# This controller implements the Poll-based delivery method for Security Event
# Tokens as described RFC 8936
#
# ref: https://datatracker.ietf.org/doc/html/rfc8936
#
module Api
  class IrsAttemptsApiController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { IdentityConfig.store.irs_attempt_api_enabled }

    skip_before_action :verify_authenticity_token
    before_action :authenticate_client
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration

    respond_to :json

    def create
      if timestamp
        result = security_event_log_result
        headers['X-Payload-Key'] = result[:key]
        headers['X-Payload-IV'] = result[:iv]
        send_data result[:data], disposition: "filename=#{result[:filename]}"
      else
        render json: { status: :unprocessable_entity, description: 'Invalid timestamp parameter' },
               status: :unprocessable_entity
      end
      analytics.irs_attempts_api_events(**analytics_properties)
    end

    private

    def authenticate_client
      bearer, csp_id, token = request.authorization.split(' ', 3)
      if bearer != 'Bearer' || !valid_auth_tokens.include?(token) ||
         csp_id != IdentityConfig.store.irs_attempt_api_csp_id
        render json: { status: 401, description: 'Unauthorized' }, status: :unauthorized
      end
    end

    def security_event_tokens
      return {} unless timestamp
      @security_event_tokens ||= redis_client.read_events(timestamp: timestamp)
    end

    def security_event_log_result
      json = security_event_tokens.to_json
      gzip = Zlib::gzip(json)

      cipher = OpenSSL::Cipher::AES.new(128, :cbc)
      cipher.encrypt
      key = cipher.random_key
      iv = cipher.random_iv
      encrypted_gzip = cipher.update(gzip) + cipher.final
      digest = Digest::SHA256.hexdigest(encrypted_gzip)
      decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
      pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)
      encrypted_key = pub_key.public_encrypt(key)

      filename = "FCI-#{IdentityConfig.store.irs_attempt_api_csp_id}_#{timestamp.strftime("%Y%m%dT%HZ")}_#{digest}.json.gz"

      {
        filename: filename,
        iv: Base64.strict_encode64(iv),
        encrypted_key: Base64.strict_encode64(encrypted_key),
        data: Base64.strict_encode64(encrypted_gzip),
      }
    end

    def redis_client
      @redis_client ||= IrsAttemptsApi::RedisClient.new
    end

    def valid_auth_tokens
      IdentityConfig.store.irs_attempt_api_auth_tokens
    end

    def analytics_properties
      {
        rendered_event_count: security_event_tokens.keys.count,
        timestamp: timestamp&.iso8601,
        success: timestamp.present?,
      }
    end

    def timestamp
      timestamp_param = params.permit(:timestamp)[:timestamp]
      return nil if timestamp_param.nil?

      ActiveSupport::TimeZone['UTC'].parse(timestamp_param)
    rescue ArgumentError
      nil
    end
  end
end
