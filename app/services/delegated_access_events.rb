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
# than an event of the agency's own sign-in. The sign-in session's events reach the agency as
# re-mapped copies through `AttemptsApi::DelegatedRelease` and the tracker.
#
# Delivery is best-effort and additive: a failure or an agency that is not enrolled never affects
# the person's sign-in, the service provider's own Attempts events or the token request that
# produced the event.
class DelegatedAccessEvents
  EVENT_CONSENTED = 'delegated-access-consented'

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
    new(grant:, analytics:).write_to_each_recipient(
      EVENT_CONSENTED,
      application: grant.application.issuer,
      scope: grant.application.delegation_scope,
      remembered:,
      source: grant.source,
      consented_at: grant.consented_at.to_f,
    )
  end

  attr_reader :grant, :analytics

  # @param grant [TokenExchangeGrant] the approval the event belongs to
  # @param analytics [Analytics, nil] where delivery outcomes are logged; built for the person
  #   when the caller has none
  def initialize(grant:, analytics: nil)
    @grant = grant
    @analytics = analytics || Analytics.new(user: grant.user, request: nil, session: {}, sp: nil)
  end

  # Writes one event to every recipient of the approval's application.
  def write_to_each_recipient(event_type, metadata)
    grant.application.delegation_attempts_recipients.filter_map do |recipient|
      writer_for(recipient)&.write(event_type, metadata)
    end
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
    )
  end
end
