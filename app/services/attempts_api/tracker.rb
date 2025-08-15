# frozen_string_literal: true

module AttemptsApi
  class Tracker
    SKIP_AGENCY_UUID_CREATION_EVENT_TYPES = [
      'login-email-and-password-auth',
      'forgot-password-email-sent',
    ].freeze
    attr_reader :session_id, :enabled_for_session, :request, :user, :sp, :cookie_device_uuid,
                :sp_request_uri

    def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:,
                   sp_request_uri:, enabled_for_session:)
      @session_id = session_id
      @request = request
      @user = user
      @sp = sp
      @cookie_device_uuid = cookie_device_uuid
      @sp_request_uri = sp_request_uri
      @enabled_for_session = enabled_for_session
    end
    include TrackerEvents

    def track_event(event_type, metadata = {})
      return unless enabled?

      extra_metadata =
        if metadata.has_key?(:failure_reason) &&
           (metadata[:failure_reason].blank? || metadata[:success].present?)
          metadata.except(:failure_reason)
        else
          metadata
        end

      event_metadata = {
        user_agent: request&.user_agent,
        unique_session_id: hashed_session_id,
        user_uuid: agency_uuid(event_type: event_type),
        device_id: cookie_device_uuid,
        user_ip_address: request&.remote_ip,
        application_url: sp_request_uri,
        language: user&.email_language || I18n.locale.to_s,
        client_port: CloudFrontHeaderParser.new(request).client_port,
        aws_region: IdentityConfig.store.aws_region,
        google_analytics_cookies: google_analytics_cookies(request),
      }

      event_metadata.merge!(extra_metadata)

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
      )

      jwe = event.to_jwe(
        issuer: sp.issuer,
        public_key: sp.attempts_public_key,
      )

      redis_client.write_event(
        event_key: event.jti,
        jwe: jwe,
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

    def self.infinite_loop(sleep_time: 0.1, num_events: 10, total_events: 100)
      # redis_client = AttemptsApi::RedisClient.new
      sleep_time = 0.1
      num_events = 10_000
      total_events = 500_000
      user = EmailAddress.confirmed.first.user
      request = ActionDispatch::Request.new(
        'HTTP_HOST' => 'www.login.gov',
        'PATH_INFO' => '/foo/bar',
        'rack.url_scheme' => 'https',
      )
      service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:sinatra')
      cookie_uuid = SecureRandom.hex(UserEventCreator::COOKIE_BYTES)

      tracker = AttemptsApi::Tracker.new(
        session_id: 'abc123',
        request: request,
        user: user,
        sp: service_provider,
        cookie_device_uuid: cookie_uuid,
        sp_request_uri: 'www.example.com',
        enabled_for_session: true,
      )

      total_saved_events = 0
      while total_saved_events < total_events do
        puts "#{Time.zone.now}: creating #{num_events} events"
        num_events.times do
          tracker.forgot_password_email_confirmed(success: true)
          total_saved_events += 1
        end
        sleep sleep_time
      end
    end

    def self.infinite_loop_poll
      client_id = 'urn:gov:gsa:openidconnect:sp:sinatra'
      # shared_secret = ''
      # attempts_url = 'https://idp.dev.identitysandbox.gov/api/attempts/poll'
      shared_secret = ''
      attempts_url = 'https://idp.mhenke.identitysandbox.gov/api/attempts/poll'
      # attempts_url = 'http://localhost:3000/api/attempts/poll'
      sp_private_key = OpenSSL::PKey::RSA.new(File.read('/Users/mitchellehenke/projects/identity-oidc-sinatra/config/demo_sp.key'))
      auth = "Bearer #{client_id} #{shared_secret}"

      acks = []
      while true do
        params = {
          maxEvents: 1_000,
          acks: acks,
        }

        connection = Faraday.new(
          url: attempts_url,
          headers: { 'Authorization' => auth, 'Content-Type' => 'application/json' },
        )

        response = connection.post do |conn|
          conn.body = params.to_json
        end;1
        if response.status != 200
          # rubocop:disable Layout/LineLength
          Rails.logger.info("got #{response.status} trying to query #{attempts_url}")
          # rubocop:enable Layout/LineLength
          # raise RuntimeError.new(response.body) if response.status != 200
        end

        sets = JSON.parse(response.body)['sets']

        keys = sets.keys
        acks = keys
        values = sets.values.map do |jwe|
          JSON.parse(JWE.decrypt(jwe, sp_private_key))
        end

        puts values.count
      end
    end

    private

    def google_analytics_cookies(request)
      return nil unless request&.cookies
      request.cookies.filter do |key, value|
        key == '_ga' && value.start_with?('GA1.') ||
          key.start_with?('_ga_') && value.start_with?('GS2.')
      end
    end

    def agency_uuid(event_type:)
      return nil unless user&.id && sp
      skip_create = SKIP_AGENCY_UUID_CREATION_EVENT_TYPES.include?(event_type)

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

    def enabled?
      IdentityConfig.store.attempts_api_enabled && @enabled_for_session
    end

    def redis_client
      @redis_client ||= AttemptsApi::RedisClient.new
    end
  end
end
