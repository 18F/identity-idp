module IrsAttemptsApi
  class AttemptEvent
    attr_accessor :jti, :iat, :event_type, :session_id, :occurred_at, :event_metadata

    def initialize(
      event_type:,
      session_id:,
      occurred_at:,
      event_metadata:,
      jti: SecureRandom.uuid,
      iat: Time.zone.now.to_i
    )
      @jti = jti
      @iat = iat
      @event_type = event_type
      @session_id = session_id
      @occurred_at = occurred_at
      @event_metadata = event_metadata
    end

    def payload
      {
        jti: jti,
        iat: iat,
        iss: Rails.application.routes.url_helpers.root_url,
        aud: IdentityConfig.store.irs_attempt_api_audience,
        events: {
          long_event_type => event_data,
        },
      }
    end

    def payload_json
      @payload_json ||= payload.to_json
    end

    private

    def event_data
      {
        'subject' => {
          'subject_type' => 'session',
          'session_id' => session_id,
        },
        'occurred_at' => occurred_at.to_f,
      }.merge(event_metadata || {})
    end

    def long_event_type
      dasherized_name = event_type.to_s.dasherize
      "https://schemas.login.gov/secevent/irs-attempts-api/event-type/#{dasherized_name}"
    end
  end
end
