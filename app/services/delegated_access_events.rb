# frozen_string_literal: true

# Fraud-signal events for delegated access, delivered through the Attempts API to the agency
# whose application a service provider acts at.
#
# An agency receives these events under its own Attempts issuer, encrypted to its own key, so it
# can see the sign-in behind a delegated token the way it would see a direct sign-in. Every
# delegated event carries `delegation_id` (the same value the token's verification returns, so the
# agency can join events to API calls) and `actor_issuer` (the service provider acting for the
# person), and attributes the person by their identifier at the agency, never by the service
# provider's.
#
# The events here are written by Login.gov's server for the agency alone, outside any browser
# session of the agency's: the exchange, refresh and revocation paths run without a session or a
# `current_sp` (so the ordinary `attempts_api_tracker` is unavailable and would in any case address
# the service provider), and the consent decision is the person's answer about the agency rather
# than an event of the agency's own sign-in. They carry no IP address, user agent or device: the
# request behind them, when there is one, came from the service provider's server, not from the
# person. The person's Login.gov session appears only as the same opaque hash the session's
# sign-in events carry (`unique_session_id`), so the agency can join the two without learning the
# session identifier. The sign-in session's events themselves reach the agency as re-mapped copies
# through `AttemptsApi::DelegatedRelease` and the tracker.
#
# Delivery is best-effort and additive: a failure or an agency that is not enrolled never affects
# the person's sign-in, the service provider's own Attempts events or the token request that
# produced the event.
class DelegatedAccessEvents
  # A re-approval of the same application replaces the earlier approval and carries its live
  # tokens over, so nothing ended for the agency; it is not reported as a revocation.
  UNREPORTED_REVOCATION_REASONS = %w[superseded_by_new_consent].freeze

  # Delivery to agencies is off unless delegated access is on, this delivery is switched on
  # separately, and the Attempts API itself is on.
  def self.enabled?
    IdentityConfig.store.token_exchange_enabled &&
      IdentityConfig.store.token_exchange_attempts_delivery_enabled &&
      IdentityConfig.store.attempts_api_enabled
  end

  # The person approved one application for a service provider, or a remembered approval was
  # reused for a sign-in without the consent screen. Written to each recipient of the
  # application, once per approval and once per reuse. Called by `AttemptsApi::DelegatedRelease`.
  # @param grant [TokenExchangeGrant] the live approval
  # @param remembered [Boolean] true when an earlier approval was reused rather than given now
  # @return [Array<AttemptsApi::AttemptEvent>] the events written
  def self.consented(grant, remembered:, analytics: nil)
    new(grant:, analytics:).write_to_each_recipient do |writer|
      writer.delegated_access_consented(
        application: grant.application.issuer,
        scope: grant.application.delegation_scope,
        remembered:,
        source: grant.source,
        consented_at: grant.consented_at.to_f,
      )
    end
  end

  # A delegated token was issued by exchange for one API. Written to that API's recipient. Called
  # by `OpenidConnectTokenExchangeForm` once the token is live.
  # @param issued [TokenExchangeToken] the issuance record
  # @return [AttemptsApi::AttemptEvent, nil]
  def self.token_issued(issued, analytics: nil)
    new(grant: issued.grant, analytics:).write_to(issued.resource_server.attempts_recipient) do |w|
      w.delegated_access_token_issued(**token_metadata(issued))
    end
  end

  # A delegated token was renewed with a refresh token for one API. Written to that API's
  # recipient. Called by the refresh grant once the renewed token is live.
  # @param issued [TokenExchangeToken] the issuance record of the renewed token
  # @return [AttemptsApi::AttemptEvent, nil]
  def self.token_refreshed(issued, analytics: nil)
    new(grant: issued.grant, analytics:).write_to(issued.resource_server.attempts_recipient) do |w|
      w.delegated_access_token_refreshed(**token_metadata(issued))
    end
  end

  # Access under an approval ended, with the reason. Called by `TokenExchangeGrant#revoke!` for
  # every approval revocation (`user_revoked`, `sp_disconnected`, `account_suspended`,
  # `account_deleted`, `client_revoked`), written to each recipient of the application; and by
  # refresh-token reuse detection with `reason: 'refresh_token_reuse'` and the `resource_server:`
  # whose refresh family ended, written to that API's recipient alone. A superseding re-approval
  # is not a revocation and is not reported.
  # @param grant [TokenExchangeGrant] the approval
  # @param reason [String]
  # @param resource_server [TokenExchangeResourceServer, nil] when only one API's access ended
  # @return [Array<AttemptsApi::AttemptEvent>] the events written
  def self.access_revoked(grant:, reason:, resource_server: nil, analytics: nil)
    return [] if UNREPORTED_REVOCATION_REASONS.include?(reason)

    events = new(grant:, analytics:)
    write = lambda do |writer|
      writer.delegated_access_revoked(
        application: grant.application.issuer, resource: resource_server&.identifier, reason:,
      )
    end
    if resource_server
      Array(events.write_to(resource_server.attempts_recipient, &write))
    else
      events.write_to_each_recipient(&write)
    end
  end

  # What the agency learns about a token: which API and scope, the assurance the sign-in carried,
  # the token's shape and when it ends. Never the token itself or anything derived from it.
  def self.token_metadata(issued)
    {
      application: issued.grant.application.issuer,
      resource: issued.resource_server.identifier,
      scope: issued.scope,
      ial: issued.ial,
      aal: issued.aal,
      token_type: issued.token_type,
      token_format: issued.token_format,
      expires_at: issued.expires_at.to_i,
    }
  end
  private_class_method :token_metadata

  attr_reader :grant, :analytics

  # @param grant [TokenExchangeGrant] the approval the event belongs to
  # @param analytics [Analytics, nil] where delivery outcomes are logged; built for the person
  #   when the caller has none
  def initialize(grant:, analytics: nil)
    @grant = grant
    @analytics = analytics || Analytics.new(user: grant.user, request: nil, session: {}, sp: nil)
  end

  # Writes one event to every recipient of the approval's application.
  # @yieldparam writer [AttemptsApi::DelegatedEventWriter] addressed to one recipient; the block
  #   calls the TrackerEvents method for the event
  # @return [Array<AttemptsApi::AttemptEvent>] the events written
  def write_to_each_recipient(&)
    grant.application.delegation_attempts_recipients.filter_map do |recipient|
      write_to(recipient, &)
    end
  end

  # Writes one event to one recipient.
  # @yieldparam writer [AttemptsApi::DelegatedEventWriter] addressed to the recipient
  # @return [AttemptsApi::AttemptEvent, nil] the event written, or nil when nothing was delivered
  def write_to(recipient)
    writer = writer_for(recipient)
    yield writer if writer
  end

  # A writer addressed to one recipient, or nil when nothing can reach it. The person's identifier
  # at the recipient's agency is created here if the agency has never seen them; it is never
  # created for a recipient that cannot receive anything.
  # @param recipient [ServiceProvider]
  # @return [AttemptsApi::DelegatedEventWriter, nil]
  def writer_for(recipient)
    return nil unless self.class.enabled? && recipient.attempts_api_deliverable?

    AttemptsApi::DelegatedEventWriter.new(
      recipient:,
      agency_uuid: AgencyIdentityLinker.for(
        user: grant.user, service_provider: recipient, skip_create: false,
      ).uuid,
      delegation_id: grant.delegation_id,
      actor_issuer: grant.service_provider_issuer,
      analytics:,
      extra_metadata: session_metadata,
    )
  end

  private

  # The same opaque hash of the person's Login.gov session that the tracker puts on the sign-in's
  # events, so the agency can join a token or consent event to that sign-in; nil when the person
  # has no live session.
  def session_metadata
    unique_session_id = grant.user.unique_session_id
    return {} if unique_session_id.blank?

    { unique_session_id: Digest::SHA1.hexdigest(unique_session_id) }
  end
end
