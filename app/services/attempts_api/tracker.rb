# frozen_string_literal: true

module AttemptsApi
  class Tracker
    SKIP_AGENCY_UUID_CREATION_EVENT_TYPES = [
      'login-email-and-password-auth',
      'forgot-password-email-sent',
    ].freeze

    # These are events that should be encrypted and then persisted as historical information
    LOG_HISTORY_PREFIXES = ['idv-'].freeze

    attr_reader :session_id, :enabled_for_session, :request, :user, :sp, :cookie_device_uuid,
                :sp_redirect_uri

    def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:,
                   sp_redirect_uri:, enabled_for_session:)
      @session_id = session_id
      @request = request
      @user = user
      @sp = sp
      @cookie_device_uuid = cookie_device_uuid
      @sp_redirect_uri = sp_redirect_uri
      @enabled_for_session = enabled_for_session
    end

    include TrackerEvents

    # @param extra_metadata [Hash] members added to every released event; a delegated release adds
    #   `delegation_id` and `actor_issuer` so the agency can tell the events apart
    def self.write_existing_user_events(sp:, historical_attempts: [], extra_metadata: {})
      historical_attempts.each do |event_data|
        event = HistoricalAttemptEvent.new(event_data:, sp:, extra_metadata:)

        jwe = event.to_jwe(issuer: sp.issuer, public_key: sp.attempts_public_key)

        AttemptsApi::RedisClient.new.write_event(
          event_key: event.jti,
          jwe:,
          timestamp: event.occurred_at,
          issuer: sp.issuer,
        )
      end
    end

    def track_event(event_type, metadata = {})
      return unless should_track?(event_type)

      overwrite_user_if_applicable(metadata.delete(:user_id))

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata(event_type:, metadata:),
      )

      log_history(event) if should_log_history?(event_type)
      capture_for_delegation(event)

      return unless should_send_event?

      redis_client.write_event(
        event_key: event.jti,
        jwe: jwe(event),
        timestamp: event.occurred_at,
        issuer: sp.issuer,
      )

      event
    end

    def parse_failure_reason(result)
      errors = result.to_h[:error_details]

      if errors.present?
        parsed_errors = errors.keys.index_with do |k|
          errors[k].keys
        end
      end

      parsed_errors || result.errors.presence
    end

    private

    # While a delegated-access authorization is in flight, every event is copied into the session
    # buffer for the agencies the person may approve, whether or not the service provider itself
    # is enrolled in the Attempts API. Once an agency is approved, each later event of the browser
    # session also reaches it at once as a re-mapped copy. The service provider's own event is
    # unaffected either way.
    def capture_for_delegation(event)
      return unless delegation_context.active?

      delegation_context.push_buffered_event(event)
      delegation_context.approved.each do |issuer, approval|
        recipient = delegation_recipients[issuer] ||= ServiceProvider.find_by(issuer:)
        DelegatedEventWriter.new(
          recipient:,
          agency_uuid: approval['agency_uuid'],
          delegation_id: approval['delegation_id'],
          actor_issuer: delegation_context.sp_issuer,
          analytics: delegation_analytics,
        ).forward(event)
      end
    end

    def delegation_context
      @delegation_context ||= DelegationContext.from_session(session)
    end

    def delegation_recipients
      @delegation_recipients ||= {}
    end

    def delegation_analytics
      @delegation_analytics ||= Analytics.new(
        user: user || AnonymousUser.new, request: nil, session: {}, sp:,
      )
    end

    # True when this event is being recorded only for the delegation buffer: the service provider
    # is not receiving it and it is not being kept as proofing history.
    def buffer_only?(event_type)
      !should_send_event? && !should_log_history?(event_type)
    end

    def log_history(event)
      return unless session && session['warden.user.user.session']

      if IdentityConfig.store.historical_attempts_pii_enabled
        event_data = event.as_json
      else
        event_data = {
          event_type: event.event_type,
          jti: event.jti,
          iat: event.iat,
          occurred_at: Time.zone.at(event.occurred_at).iso8601,
          event_metadata: {
            user_uuid: event.event_metadata[:user_uuid],
          },
        }.as_json

      end

      session['warden.user.user.session']['idv/attempts'] ||= []
      session['warden.user.user.session']['idv/attempts'].push(
        event_data,
      )
    end

    def session
      @request&.session
    end

    def overwrite_user_if_applicable(uuid)
      @user = User.find_by(uuid:) if user_blank? && uuid.present?
    end

    def user_blank?
      @user.blank? || @user.uuid == 'anonymous-uuid'
    end

    def jwe(event)
      event.to_jwe(
        issuer: sp.issuer,
        public_key: sp.attempts_public_key,
      )
    end

    def extra_attributes(event_type: nil) # rubocop:disable Lint/UnusedMethodArgument
      {}
    end

    def extra_metadata(event_type:, metadata:)
      failure_metadata(metadata:).merge(extra_attributes(event_type:))
    end

    def failure_metadata(metadata:)
      if metadata.has_key?(:failure_reason) &&
         (metadata[:failure_reason].blank? || metadata[:success].present?)
        metadata.except(:failure_reason)
      else
        metadata
      end
    end

    def event_metadata(event_type:, metadata:)
      {
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
      }.merge!(extra_metadata(event_type:, metadata:))
    end

    def google_analytics_cookies(request)
      return nil unless request&.cookies
      request.cookies.filter do |key, value|
        key == '_ga' && value.start_with?('GA1.') ||
          key.start_with?('_ga_') && value.start_with?('GS2.')
      end
    end

    # The buffer never carries the service provider's pairwise identifier, so buffering alone must
    # not create the person's identity at the service provider's agency ahead of the handoff.
    def agency_uuid(event_type:)
      return nil unless user&.id && sp
      skip_create = SKIP_AGENCY_UUID_CREATION_EVENT_TYPES.include?(event_type) ||
                    buffer_only?(event_type)

      if skip_create
        AgencyIdentityLinker.for(user: user, service_provider: sp, skip_create: true)&.uuid
      else
        AgencyIdentityLinker.for(user: user, service_provider: sp, skip_create: false).uuid
      end
    end

    def hashed_session_id
      return nil unless user&.unique_session_id.present?

      Digest::SHA1.hexdigest(user&.unique_session_id)
    end

    def should_track?(event_type)
      # Historical Attempts feature requires the Attempts API to be enabled globally
      return false unless IdentityConfig.store.attempts_api_enabled

      should_send_event? || should_log_history?(event_type) || delegation_context.active?
    end

    def should_log_history?(event_type)
      return false unless IdentityConfig.store.historical_attempts_api_enabled

      event_type.start_with?(*LOG_HISTORY_PREFIXES)
    end

    def should_send_event?
      @enabled_for_session
    end

    def redis_client
      @redis_client ||= AttemptsApi::RedisClient.new
    end
  end
end
