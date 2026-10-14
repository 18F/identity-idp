# frozen_string_literal: true

module AttemptsApi
  # Delivers the sign-in session's fraud signals to the agencies of the applications the person
  # has just approved for delegated access, or whose remembered approval is being reused.
  #
  # Called once per approval decision: from the consent screen after the approvals are written,
  # from the account page after an advance approval, and at the handoff when remembered approvals
  # let the consent screen be skipped. For each Attempts recipient of an approved application that
  # is enrolled with a usable key it:
  #
  # 1. creates the person's identifier at that agency if the agency has never seen them (no
  #    `identities` row: the agency is not a service provider the person signed in to);
  # 2. delivers the events buffered since the request started (`DelegationContext`), re-mapped for
  #    the agency, unless this session already delivered them to it;
  # 3. writes one `delegated-access-consented` event per approved application, marked remembered
  #    when an earlier approval is being reused;
  # 4. releases the person's stored identity-proofing history under the existing once-per-recipient
  #    rule, skipping it (and leaving the once-only flag unset) when the history is not in the
  #    session, as after a remember-device or PIV/CAC sign-in;
  # 5. when this is the sign-in's own service provider, marks the recipient approved in the session
  #    so later events of the browser session reach it as they happen.
  #
  # Applications the person did not approve are never named here, so their agencies receive
  # nothing and no identifier is created for them.
  class DelegatedRelease
    attr_reader :user, :session, :user_session, :grants, :remembered_grants, :request_id,
                :analytics

    # @param grants [Array<TokenExchangeGrant>] approvals given now
    # @param remembered_grants [Array<TokenExchangeGrant>] earlier approvals reused now
    # @param request_id [String, nil] the service provider request this release belongs to, so the
    #   handoff that follows the consent screen does not release again
    # @param analytics [Analytics]
    def initialize(user:, session:, user_session:, analytics:, grants: [], remembered_grants: [],
                   request_id: nil)
      @user = user
      @session = session
      @user_session = user_session
      @analytics = analytics
      @grants = Array(grants)
      @remembered_grants = Array(remembered_grants)
      @request_id = request_id
    end

    def call
      return unless DelegatedAccessEvents.enabled?

      preload_recipients

      approvals_by_recipient.each do |recipient, approvals|
        # An agency listed without a usable encryption key is not enrolled and receives nothing.
        next unless recipient.attempts_api_deliverable?

        release_to(recipient, approvals)
      end

      context.mark_released(request_id) if request_id.present?
    end

    private

    # @return [Hash{ServiceProvider => Array<[TokenExchangeGrant, Boolean]>}] each recipient with
    #   the approvals it covers and whether each is a reuse
    def approvals_by_recipient
      pairs = grants.map { |grant| [grant, false] } + remembered_grants.map do |grant|
        [grant, true]
      end
      pairs.each_with_object({}) do |(grant, remembered), by_recipient|
        grant.application.delegation_attempts_recipients.each do |recipient|
          (by_recipient[recipient] ||= []) << [grant, remembered]
        end
      end
    end

    # Each approval's recipients are reached through its application and that application's API
    # URLs. Load both hops up front when several approvals are grouped so grouping does not fan
    # out into one query per approval; a single approval has no fan-out to avoid.
    def preload_recipients
      records = grants + remembered_grants
      return if records.size < 2

      ::ActiveRecord::Associations::Preloader.new(
        records:,
        associations: {
          application: { token_exchange_resource_servers: :attempts_service_provider },
        },
      ).call
    end

    def release_to(recipient, approvals)
      agency_uuid = AgencyIdentityLinker.for(
        user:, service_provider: recipient, skip_create: false,
      ).uuid
      # The session's copies carry one join key per recipient: the earliest approval's, so an
      # agency with several approved applications can still join every copy to one delegation.
      lead = approvals.map(&:first).min_by(&:id)
      delegation_id = lead.delegation_id
      actor_issuer = lead.service_provider_issuer

      unless context.buffer_delivered_to?(recipient.issuer)
        DelegatedEventWriter.new(
          recipient:, agency_uuid:, delegation_id:, actor_issuer:, analytics:,
        ).forward_all(buffered_events)
        context.mark_buffer_delivered(recipient.issuer)
      end

      approvals.each do |grant, remembered|
        DelegatedAccessEvents.consented(grant, remembered:, analytics:)
      end

      release_historical(recipient, delegation_id:, actor_issuer:)

      # Later events of this browser session belong to the sign-in that is under way; they are
      # forwarded only when that sign-in is to the service provider these approvals are for.
      return unless context.sp_issuer == actor_issuer

      context.approve(issuer: recipient.issuer, delegation_id:, agency_uuid:)
    rescue StandardError => e
      # Fraud-signal delivery never blocks the person's consent, handoff or account page.
      NewRelic::Agent.notice_error(
        e, custom_params: { recipient_issuer: recipient.issuer, step: 'delegated_release' }
      )
      analytics.delegated_access_attempts_delivery(
        event_type: 'delegated_release', recipient_issuer: recipient.issuer,
        actor_issuer: approvals.first.first.service_provider_issuer, success: false,
        event_count: 0, exception: e.class.name
      )
    end

    # The stored `idv-*` history goes to each recipient once, as it does for a service provider at
    # the handoff, with the join keys added so the agency can tell a delegated release apart.
    def release_historical(recipient, delegation_id:, actor_issuer:)
      return unless IdentityConfig.store.historical_attempts_api_enabled
      return unless user.identity_verified?

      profile = user.active_profile
      releasable, _reason = HistoricalReleaseCheck.new(profile:, sp: recipient).call
      return unless releasable

      historical_attempts = Cacher.new(user, user_session).fetch
      return if historical_attempts.blank?

      Tracker.write_existing_user_events(
        sp: recipient,
        historical_attempts:,
        extra_metadata: { delegation_id:, actor_issuer: },
      )
      profile.user_proofing_event.add_sp_sent(recipient.id)
      analytics.delegated_access_attempts_delivery(
        event_type: 'historical_proofing_events', recipient_issuer: recipient.issuer,
        actor_issuer:, success: true, event_count: historical_attempts.size
      )
    end

    def buffered_events
      @buffered_events ||= context.buffered_events
    end

    def context
      @context ||= DelegationContext.from_session(session)
    end
  end
end
