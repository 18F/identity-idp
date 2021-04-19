module PushNotification
  # Delivers SETs (Security Event Tokens) via the HTTP Push protocol
  # https://tools.ietf.org/html/draft-ietf-secevent-http-push-00
  class HttpPush
    include Rails.application.routes.url_helpers

    attr_reader :event

    # shorthand for creating an instance then calling #deliver, easier to stub
    def self.deliver(event, now: Time.zone.now)
      new(event, now: now).deliver
    end

    def initialize(event, now: Time.zone.now)
      @event = event
      @now = now
    end

    def deliver
      return unless IdentityConfig.store.push_notifications_enabled

      event.user.
        service_providers.
        merge(ServiceProviderIdentity.not_deleted).
        with_push_notification_urls.each do |service_provider|
          deliver_one(service_provider)
        end
    end

    def url_options
      {}
    end

    private

    attr_reader :now

    def deliver_one(service_provider)
      deliver_local(service_provider) if IdentityConfig.store.risc_notifications_local_enabled

      if IdentityConfig.store.risc_notifications_eventbridge_enabled
        deliver_eventbridge(service_provider)
      else
        deliver_direct(service_provider)
      end
    end

    def deliver_eventbridge(service_provider)
      eventbridge_client.put_events(
        entries: [
          {
            time: now,
            source: service_provider.issuer,
            detail_type: 'notification',
            detail: jwt(service_provider),
            event_bus_name: "#{Identity::Hostdata.env}-risc-notifications",
          },
        ],
      )
    end

    def deliver_direct(service_provider)
      response = faraday.post(
        service_provider.push_notification_url,
        jwt(service_provider),
        'Accept' => 'application/json',
        'Content-Type' => 'application/secevent+jwt',
      )

      unless response.success?
        raise PushNotification::PushNotificationError, "status=#{response.status}"
      end
    rescue Faraday::TimeoutError,
           Faraday::ConnectionFailed,
           PushNotification::PushNotificationError => err
      NewRelic::Agent.notice_error(err)
    end

    def deliver_local(service_provider)
      event = {
        url: service_provider.push_notification_url,
        payload: jwt_payload(service_provider),
        jwt: jwt(service_provider),
      }
      PushNotification::LocalEventQueue.events << event
    end

    def jwt(service_provider)
      payload = jwt_payload(service_provider)

      JWT.encode(payload, AppArtifacts.store.oidc_private_key, 'RS256', typ: 'secevent+jwt')
    end

    def jwt_payload(service_provider)
      {
        iss: root_url,
        iat: now.to_i,
        exp: (now + 12.hours).to_i,
        jti: SecureRandom.hex,
        aud: service_provider.push_notification_url,
        events: {
          event.event_type => event.payload(iss_sub: agency_uuid(service_provider)),
        },
      }
    end

    def faraday
      Faraday.new { |faraday| faraday.adapter :net_http }
    end

    def agency_uuid(service_provider)
      AgencyIdentity.find_by(
        user_id: event.user.id,
        agency_id: service_provider.agency_id,
      )&.uuid ||
        ServiceProviderIdentity.find_by(
          user_id: event.user.id,
          service_provider: service_provider.issuer,
        )&.uuid
    end

    def eventbridge_client
      @eventbridge_client ||= Aws::EventBridge::Client.new(
        region: Identity::Hostdata.aws_region
      )
    end
  end
end
