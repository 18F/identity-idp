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

      # mattw: I think we should change this but this breaks tests, possibly because
      # the test calls user.identities and we need to change that still?
      event.user.
        service_providers.
        merge(ServiceProviderIdentity.not_deleted).
        merge(ServiceProviderIdentity.consented).
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

      job_arguments = {
        push_notification_url: service_provider.push_notification_url,
        jwt: jwt(service_provider),
        event_type: event.event_type,
        issuer: service_provider.issuer,
      }

      if IdentityConfig.store.risc_notifications_active_job_enabled
        RiscDeliveryJob.perform_later(**job_arguments)
      else
        RiscDeliveryJob.perform_now(**job_arguments)
      end
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

      JWT.encode(
        payload,
        AppArtifacts.store.oidc_private_key,
        'RS256',
        typ: 'secevent+jwt',
        kid: JWT::JWK.new(AppArtifacts.store.oidc_private_key).kid,
      )
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

    def agency_uuid(service_provider)
      AgencyIdentity.find_by(
        user_id: event.user.id,
        agency_id: service_provider.agency_id,
      )&.uuid ||
        # This changes breaks nothing
        ServiceProviderIdentity.consented.find_by(
          user_id: event.user.id,
          service_provider: service_provider.issuer,
        )&.uuid
    end
  end
end
