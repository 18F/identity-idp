# frozen_string_literal: true

class FraudOpsTracker < AttemptsApi::Tracker
  def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:, sp_redirect_uri:)
    super(
      session_id: session_id,
      request: request,
      user: user,
      sp: sp,
      cookie_device_uuid: cookie_device_uuid,
      sp_redirect_uri: sp_redirect_uri,
      enabled_for_session: true,
    )
  end

  def track_event(event_type, metadata = {})
    return unless enabled?

    extra_metadata =
      if metadata.has_key?(:failure_reason) &&
         (metadata[:failure_reason].blank? || metadata[:success].present?)
        metadata.except(:failure_reason)
      else
        metadata
      end

    event_metadata = {
      user_agent: request&.user_agent,
      unique_session_id: hashed_session_id,
      user_uuid: agency_uuid(event_type: event_type),
      device_id: cookie_device_uuid,
      user_ip_address: request&.remote_ip,
      application_url: sp_redirect_uri,
      language: user&.email_language || I18n.locale.to_s,
      client_port: CloudFrontHeaderParser.new(request).client_port,
      aws_region: IdentityConfig.store.aws_region,
      google_analytics_cookies: google_analytics_cookies(request),
    }

    event_metadata.merge!(extra_metadata)

    event = AttemptsApi::AttemptEvent.new(
      event_type: event_type,
      session_id: session_id,
      occurred_at: Time.zone.now,
      event_metadata: event_metadata,
    )

    payload_json = event.payload(issuer: 'fraud-ops-internal').to_json

    redis_client.write_event(
      event_key: event.jti,
      jwe: payload_json,
      timestamp: Time.zone.now,
      issuer: 'fraud-ops-internal',
    )
  end

  private

  def enabled?
    IdentityConfig.store.fraud_ops_tracker_enabled
  end

  def redis_client
    @redis_client ||= FraudOpsRedisClientWrapper.new
  end
end
