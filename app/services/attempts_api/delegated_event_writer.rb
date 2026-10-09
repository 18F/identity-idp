# frozen_string_literal: true

module AttemptsApi
  # Writes Attempts API events for one agency recipient of a delegated session.
  #
  # Two kinds of event go through here. A *forwarded* event is one the tracker recorded for the
  # service provider's browser session, re-mapped for the agency: the copy keeps the event type,
  # timestamps, `subject.session_id` (still the service provider's own session identifier, per the
  # published schema), IP address, user agent, device id, `application_url` and every
  # event-specific field; it replaces `user_uuid` with the person's identifier at the agency,
  # drops the service provider's Google Analytics cookies, and adds `delegation_id` and
  # `actor_issuer`. A *written* event is produced by Login.gov's server for the agency alone (the
  # consent and token events); it carries no network details, because the request behind it, when
  # there is one, came from the service provider's server and not from the person, and the IdP
  # session appears only as the same opaque hash the session's other events carry.
  #
  # Every delivery is best-effort: a failure is reported and logged, never raised, so a broken
  # agency configuration cannot affect the person or the service provider.
  class DelegatedEventWriter
    attr_reader :recipient, :agency_uuid, :delegation_id, :actor_issuer

    # @param recipient [ServiceProvider] the record whose Attempts credentials receive the events
    # @param agency_uuid [String] the person's identifier at the recipient's agency
    # @param delegation_id [String] join key the agency also sees at token verification
    # @param actor_issuer [String] issuer of the service provider acting for the person
    # @param analytics [Analytics] where delivery outcomes are logged
    def initialize(recipient:, agency_uuid:, delegation_id:, actor_issuer:, analytics:)
      @recipient = recipient
      @agency_uuid = agency_uuid
      @delegation_id = delegation_id
      @actor_issuer = actor_issuer
      @analytics = analytics
    end

    # Whether anything can reach this recipient: delivery is switched on and the recipient is
    # enrolled with a usable encryption key.
    def enabled?
      DelegatedAccessEvents.enabled? && recipient&.attempts_api_deliverable?
    end

    # Re-maps one session event for the agency and writes the copy.
    # @param event [AttemptEvent] the event as recorded for the service provider
    # @return [AttemptEvent, nil] the copy written, or nil when nothing was delivered
    def forward(event)
      deliver([remap(event)], event_type: event.event_type.to_s).first
    end

    # Re-maps and writes a batch of session events (the buffered sign-in), logged as one outcome.
    # @param events [Array<AttemptEvent>]
    # @return [Array<AttemptEvent>] the copies written
    def forward_all(events)
      return [] if events.empty?

      deliver(events.map { |event| remap(event) }, event_type: 'buffered_session_events')
    end

    # Writes one server-side event for the agency.
    # @param event_type [String] the Attempts event type, for example `delegated-access-consented`
    # @param metadata [Hash] the event's own members
    # @return [AttemptEvent, nil] the event written, or nil when nothing was delivered
    def write(event_type, metadata)
      event = AttemptEvent.new(
        event_type:,
        # `subject.session_id` is, by the published schema, the service provider's own session
        # identifier for the sign-in; a server-to-server event has none.
        session_id: nil,
        occurred_at: Time.zone.now,
        event_metadata: base_metadata.merge(metadata),
      )
      deliver([event], event_type:).first
    end

    private

    attr_reader :analytics

    def remap(event)
      metadata = (event.event_metadata || {}).symbolize_keys
        .except(:user_uuid, :google_analytics_cookies)
        .merge(user_uuid: agency_uuid, delegation_id:, actor_issuer:)

      AttemptEvent.new(
        jti: event.jti,
        iat: event.iat,
        event_type: event.event_type,
        session_id: event.session_id,
        occurred_at: event.occurred_at,
        event_metadata: metadata,
      )
    end

    # The members every server-side delegated event carries; the event-specific ones are merged
    # on top. No IP address, user agent, port, device or analytics cookies: see the class comment.
    def base_metadata
      {
        user_uuid: agency_uuid,
        delegation_id:,
        actor_issuer:,
        application_url: nil,
        language: I18n.locale.to_s,
        aws_region: IdentityConfig.store.aws_region,
      }
    end

    # Encrypts each event to the recipient's key and stores it under the recipient's issuer, the
    # same way `Tracker#track_event` stores a service provider's own events.
    def deliver(events, event_type:)
      skipped = skipped_reason
      if skipped
        log(event_type:, success: false, skipped_reason: skipped, event_count: events.size)
        return []
      end

      public_key = recipient.attempts_public_key
      redis_client = RedisClient.new
      events.each do |event|
        redis_client.write_event(
          event_key: event.jti,
          jwe: event.to_jwe(issuer: recipient.issuer, public_key:),
          timestamp: event.occurred_at,
          issuer: recipient.issuer,
        )
      end
      log(event_type:, success: true, event_count: events.size)
      events
    rescue StandardError => e
      NewRelic::Agent.notice_error(
        e, custom_params: { recipient_issuer: recipient&.issuer, event_type: }
      )
      log(event_type:, success: false, exception: e.class.name, event_count: events.size)
      []
    end

    def skipped_reason
      return 'delivery_disabled' unless DelegatedAccessEvents.enabled?
      return 'recipient_not_enrolled' unless recipient&.attempts_api_deliverable?

      nil
    end

    def log(event_type:, success:, event_count:, skipped_reason: nil, exception: nil)
      analytics.delegated_access_attempts_delivery(
        event_type:,
        recipient_issuer: recipient&.issuer,
        actor_issuer:,
        success:,
        event_count:,
        skipped_reason:,
        exception:,
      )
    end
  end
end
