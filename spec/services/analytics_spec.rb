require 'rails_helper'

RSpec.describe Analytics do
  let(:analytics_attributes) do
    {
      user_id: current_user.uuid,
      new_event: true,
      path: path,
      session_duration: nil,
      locale: I18n.locale,
      git_sha: IdentityConfig::GIT_SHA,
      git_branch: IdentityConfig::GIT_BRANCH,
      event_properties: {},
    }.merge(request_attributes)
  end

  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      browser_name: 'Unknown Browser',
      browser_version: '0.0',
      browser_platform_name: 'Unknown',
      browser_platform_version: '0',
      browser_device_name: 'Unknown',
      browser_mobile: false,
      browser_bot: false,
      hostname: FakeRequest.new.host,
      pid: Process.pid,
      service_provider: 'http://localhost:3000',
      trace_id: nil,
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }
  let(:current_user) { build_stubbed(:user, uuid: '123') }
  let(:request) { FakeRequest.new }
  let(:path) { 'fake_path' }
  let(:success_state) { 'GET|fake_path|Trackable Event' }
  let(:session) { {} }

  subject(:analytics) do
    Analytics.new(
      user: current_user,
      request: request,
      sp: 'http://localhost:3000',
      session: session,
      ahoy: ahoy,
    )
  end

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      stub_const(
        'IdentityConfig::GIT_BRANCH',
        'my branch',
      )

      expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

      analytics.track_event('Trackable Event')
    end

    it 'does not track unique events and paths when an event fails' do
      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(
          new_event: nil,
          event_properties: { success: false },
        ),
      )

      analytics.track_event('Trackable Event', { success: false })
    end

    it 'tracks the user passed in to the track_event method' do
      tracked_user = build_stubbed(:user, uuid: '456')

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(user_id: tracked_user.uuid),
      )

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end

    context 'tracing headers' do
      let(:amazon_trace_id) { SecureRandom.hex }
      let(:request) do
        FakeRequest.new(headers: { 'X-Amzn-Trace-Id' => amazon_trace_id })
      end

      it 'includes the tracing header as trace_id' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(trace_id: amazon_trace_id))

        analytics.track_event('Trackable Event')
      end
    end

    it 'includes the locale of the current request' do
      locale = :fr
      allow(I18n).to receive(:locale).and_return(locale)

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(locale: locale),
      )

      analytics.track_event('Trackable Event')
    end

    it 'does not alert when pii_like_keypaths is passed' do
      allow(ahoy).to receive(:track) do |_name, attributes|
        # does not forward :pii_like_keypaths
        expect(attributes.to_s).to_not include('pii_like_keypaths')
      end

      expect do
        analytics.track_event(
          'Trackable Event',
          mfa_method_counts: { phone: 1 },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        )
      end.to_not raise_error
    end

    it 'does not alert when pii values are inside words' do
      expect(ahoy).to receive(:track)

      stub_const('Idp::Constants::MOCK_IDV_APPLICANT', zipcode: '12345')

      expect do
        analytics.track_event(
          'Trackable Event',
          some_uuid: '12345678-1234-1234-1234-123456789012',
        )
      end.to_not raise_error
    end
  end

  it 'tracks session duration' do
    freeze_time do
      analytics = Analytics.new(
        user: current_user,
        request: request,
        sp: 'http://localhost:3000',
        session: { session_started_at: 7.seconds.ago },
        ahoy: ahoy,
      )

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(session_duration: 7.0),
      )

      analytics.track_event('Trackable Event')
    end
  end

  it 'errors when undocumented parameters are sent' do
    expect do
      analytics.idv_phone_confirmation_otp_submitted(
        success: true,
        errors: true,
        code_expired: true,
        code_matches: true,
        second_factor_attempts_count: true,
        second_factor_locked_at: true,
        proofing_components: true,
        some_new_undocumented_keyword: true,
      )
    end.to raise_error(FakeAnalytics::UndocumentedParams, /some_new_undocumented_keyword/)
  end

  it 'does not error when undocumented params are allowed', allowed_extra_analytics: [:fun_level] do
    expect(ahoy).to receive(:track).with(
      kind_of(String),
      hash_including(event_properties: hash_including(:fun_level)),
    )

    analytics.idv_phone_confirmation_otp_submitted(
      success: true,
      errors: true,
      code_expired: true,
      code_matches: true,
      second_factor_attempts_count: true,
      second_factor_locked_at: true,
      proofing_components: true,
      fun_level: 1000,
    )
  end

  it 'does not error when undocumented params are allowed via *', allowed_extra_analytics: [:*] do
    expect(ahoy).to receive(:track).with(
      kind_of(String),
      hash_including(event_properties: hash_including(:fun_level)),
    )

    analytics.idv_phone_confirmation_otp_submitted(
      success: true,
      errors: true,
      code_expired: true,
      code_matches: true,
      second_factor_attempts_count: true,
      second_factor_locked_at: true,
      proofing_components: true,
      fun_level: 1000,
    )
  end

  it 'does not error when string tags are documented as options' do
    expect(ahoy).to receive(:track).with(
      kind_of(String),
      hash_including(event_properties: hash_including('DocumentName')),
    )

    analytics.idv_doc_auth_submitted_image_upload_vendor(
      success: nil,
      errors: nil,
      exception: nil,
      state: nil,
      state_id_type: nil,
      async: nil,
      submit_attempts: nil,
      remaining_submit_attempts: nil,
      client_image_metrics: nil,
      flow_path: nil,
      liveness_checking_required: nil,
      'DocumentName' => 'some_name',
    )
  end

  context 'with an SP request vtr saved in the session' do
    context 'identity verified' do
      let(:session) { { sp: { vtr: ['C1.P1'] } } }
      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            component_values: { 'C1' => true, 'C2' => true, 'P1' => true },
            identity_proofing: true,
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end

    context 'phishing resistant and requiring biometric comparison' do
      let(:session) { { sp: { vtr: ['Ca.Pb'] } } }
      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            biometric_comparison: true,
            component_values: {
              'C1' => true,
              'C2' => true,
              'Ca' => true,
              'P1' => true,
              'Pb' => true,
            },
            identity_proofing: true,
            phishing_resistant: true,
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end
  end

  context 'with SP request acr_values saved in the session' do
    context 'legacy IAL1' do
      let(:session) { { sp: { acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF } } }
      let(:expected_attributes) do
        {
          sp_request: {
            component_values: { 'ial/1' => true },
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end

    context 'legacy IAL2' do
      let(:session) { { sp: { acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF } } }
      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            component_values: { 'ial/2' => true },
            identity_proofing: true,
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end

    context 'legacy IALMAX' do
      let(:session) { { sp: { acr_values: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF } } }
      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            component_values: { 'ial/0' => true },
            ialmax: true,
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end
  end
end
