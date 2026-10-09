# frozen_string_literal: true

module AttemptsApi
  # Session-backed record of an in-flight delegated-access authorization, read by the Attempts
  # tracker on every request of the sign-in session.
  #
  # While a service provider's authorization request carrying `token_exchange:*` scopes is in
  # flight, the agencies that could receive the session's fraud signals do not yet have the
  # person's approval, so nothing can be delivered to them. Instead every Attempts event of the
  # session is copied into a buffer here, each copy KMS-encrypted like the identity-proofing
  # history in `Cacher`, and released to the agencies of the applications the person approves
  # (`DelegatedRelease`). After approval the agencies are kept so later events of the same browser
  # session (login completed, re-authentication, MFA changes, logout, timeout, rate limits) reach
  # them as they happen.
  #
  # Everything lives in the Rails session and is gone when the session ends. The context sits at
  # the session root rather than in the Devise user session because sign-in events (failed
  # passwords, rate limits) happen before a user session exists, and the whole-session encryptor
  # refuses plaintext carrying keys such as `email`, which those events carry.
  class DelegationContext
    SESSION_KEY = 'delegation_context'
    BUFFER_KEY = 'delegated_attempts_buffer'
    # A session's sign-in rarely produces more than a few dozen events; the cap keeps a flood of
    # rate-limit events from growing the session without bound. The earliest events (the sign-in
    # itself) are the ones kept.
    MAX_BUFFERED_EVENTS = 200

    def self.from_session(session)
      new(session)
    end

    def initialize(session)
      @session = session
    end

    # Records a new delegation request. Candidates are the Attempts recipients of the requested
    # applications that are enrolled in the Attempts API; an agency not enrolled never receives
    # anything, so it is not a candidate. Agencies approved earlier in the same browser session
    # stay approved: their delegated session is still live.
    def start(request_id:, sp_issuer:, candidate_issuers:)
      return if session.nil?

      session[SESSION_KEY] = (data || {}).merge(
        'request_id' => request_id,
        'sp_issuer' => sp_issuer,
        'candidates' => Array(candidate_issuers).uniq,
      )
    end

    def present?
      data.present?
    end

    # True while events must be captured: delivery is switched on and either a request with at
    # least one enrolled candidate is in flight or an approved agency's delegated session is live.
    def active?
      return false unless present? && DelegatedAccessEvents.enabled?

      candidate_issuers.any? || approved.any?
    end

    def request_id
      data&.dig('request_id')
    end

    def sp_issuer
      data&.dig('sp_issuer')
    end

    def candidate_issuers
      Array(data&.dig('candidates'))
    end

    # @return [Hash{String => Hash}] recipient issuer => { 'delegation_id', 'agency_uuid' }
    def approved
      data&.dig('approved') || {}
    end

    def approved_issuers
      approved.keys
    end

    # Keeps an approved recipient so later events of this browser session reach it. The
    # delegation id is the join key the copies carry; the agency uuid is the person's identifier at
    # that agency, resolved once here so each later event does not look it up again.
    def approve(issuer:, delegation_id:, agency_uuid:)
      update do |d|
        d['approved'] = approved.merge(
          issuer => { 'delegation_id' => delegation_id, 'agency_uuid' => agency_uuid },
        )
      end
    end

    # Whether the buffered events were already released for this authorization (the consent
    # screen released them, so the handoff that follows must not release them again).
    def released_for?(request_id)
      request_id.present? && data&.dig('released_request_id') == request_id
    end

    def mark_released(request_id)
      update { |d| d['released_request_id'] = request_id }
    end

    # The buffer is delivered at most once per recipient in a session; an agency approved again
    # later in the session receives only a new consent event and the live events.
    def buffer_delivered_to?(issuer)
      Array(data&.dig('buffer_delivered_to')).include?(issuer)
    end

    def mark_buffer_delivered(issuer)
      update { |d| d['buffer_delivered_to'] = (Array(d['buffer_delivered_to']) | [issuer]) }
    end

    # Appends one event to the buffer. The service provider's pairwise identifier and Google
    # Analytics cookies are never re-mapped to an agency, so they are dropped before encryption.
    def push_buffered_event(event)
      return if session.nil?
      return if buffered_event_count >= MAX_BUFFERED_EVENTS

      serialized = {
        'jti' => event.jti,
        'iat' => event.iat,
        'event_type' => event.event_type.to_s,
        'session_id' => event.session_id,
        'occurred_at' => Time.zone.at(event.occurred_at).iso8601(6),
        'event_metadata' => (event.event_metadata || {}).except(
          :user_uuid, :google_analytics_cookies, 'user_uuid', 'google_analytics_cookies'
        ),
      }.to_json
      session[BUFFER_KEY] = Array(session[BUFFER_KEY]) + [encryptor.kms_encrypt(serialized)]
    end

    # @return [Array<AttemptEvent>] the buffered events, decrypted, oldest first
    def buffered_events
      Array(session&.dig(BUFFER_KEY)).map do |ciphertext|
        data = JSON.parse(encryptor.kms_decrypt(ciphertext))
        AttemptEvent.new(
          jti: data['jti'],
          iat: data['iat'],
          event_type: data['event_type'],
          session_id: data['session_id'],
          occurred_at: Time.zone.parse(data['occurred_at']),
          event_metadata: data['event_metadata'].symbolize_keys,
        )
      end
    end

    def buffered_event_count
      Array(session&.dig(BUFFER_KEY)).size
    end

    def clear
      return if session.nil?

      session.delete(SESSION_KEY)
      session.delete(BUFFER_KEY)
    end

    private

    attr_reader :session

    def data
      session&.dig(SESSION_KEY)
    end

    def update
      return if session.nil?

      d = (data || {}).dup
      yield d
      session[SESSION_KEY] = d
    end

    def encryptor
      @encryptor ||= SessionEncryptor.new
    end
  end
end
