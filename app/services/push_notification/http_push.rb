module PushNotification
  # Delivers SETs (Security Event Tokens) via the HTTP Push protocol
  # https://tools.ietf.org/html/draft-ietf-secevent-http-push-00
  class HttpPush
    include Rails.application.routes.url_helpers

    attr_reader :event

    def initialize(event)
      @event = event
    end

    def deliver
      event.user.
        service_providers.
        includes(:agency).
        with_push_notification_urls.each do |service_provider|
          deliver_one(service_provider)
        end
    end

    private

    def deliver_one(service_provider)
      Faraday.new { |faraday| faraday.adapter :net_http }.
        post(
          service_provider.push_notification_url,
          jwt_payload(service_provider),
          'Accept' => 'application/json',
          'Content-Type' => 'application/secevent+jwt',
        )
    end

    def jwt_payload(service_provider)
      iat = Time.zone.now.to_i
      {
        iss: root_url,
        iat: iat,
        exp: iat + 12.hours.to_i,
        jti: SecureRandom.hex,
        aud: service_provider.push_notification_url,
        events: {
          event.event_type => event.payload(iss_sub: agency_uuid(service_provider))
        },
      }
    end

    def agency_uuid(service_provider)
      AgencyIdentity.find_by(user_id: user.id, agency_id: service_provider.agency_id)&.uuid ||
        Identity.where(user_id: user.id, service_provider: service_provider.issuer)&.uuid
    end
  end
end

# event = PushNotification::IdentifierChangedEvent.new(user: user, email: email)
# PushNotification::HttpPush.new(event).deliver
