require 'rails_helper'

RSpec.describe Analytics do
  let(:analytics_attributes) do
    {
      user_id: current_user.uuid,
      new_event: true,
      path: path,
      service_provider: 'http://localhost:3000',
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

    it 'does not track nil values' do
      expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

      analytics.track_event('Trackable Event', { example: nil })
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
        expect(ahoy).to receive(:track)
          .with('Trackable Event', hash_including(trace_id: amazon_trace_id))

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

    context 'with A/B tests' do
      let(:ab_tests) do
        {
          FOO_TEST: AbTest.new(
            experiment_name: 'Test 1',
            buckets: {
              bucket_a: 50,
              bucket_b: 50,
            },
            should_log:,
          ) do |user:, **|
            user.id
          end,
        }
      end

      let(:should_log) {}

      before do
        allow(AbTests).to receive(:all).and_return(ab_tests)
      end

      it 'does not include ab_tests in logged event' do
        expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

        analytics.track_event('Trackable Event')
      end

      context 'for an included test' do
        let(:should_log) { /Trackable/ }

        it 'includes ab_test bucket detail in logged event' do
          expect(ahoy).to receive(:track).with(
            'Trackable Event',
            analytics_attributes.merge(
              ab_tests: {
                foo_test: {
                  bucket: kind_of(Symbol),
                },
              },
            ),
          )

          analytics.track_event('Trackable Event')
        end
      end
    end

    context 'when no request specified' do
      let(:request) { nil }
      context 'but an SP was specified via initializer' do
        it 'logs the SP' do
          expect(ahoy).to receive(:track).with(
            'Trackable Event',
            hash_including(service_provider: 'http://localhost:3000'),
          )
          analytics.track_event('Trackable Event')
        end
      end
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

  context 'with an SP request vtr saved in the session' do
    context 'identity verified' do
      let(:session) { { sp: { vtr: ['C1.P1'] } } }
      let(:component_names) { ['C1', 'C2', 'P1'] }
      let(:component_values) { component_names.index_with(true) }
      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            component_names:,
            component_values:,
            identity_proofing: true,
            component_separator: '.',
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track)
          .with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end

    context 'phishing resistant and requiring facial match comparison' do
      let(:session) { { sp: { vtr: ['Ca.Pb'] } } }
      let(:component_names) { ['C1', 'C2', 'Ca', 'P1', 'Pb'] }
      let(:component_values) { component_names.index_with(true) }

      let(:expected_attributes) do
        {
          sp_request: {
            aal2: true,
            facial_match: true,
            two_pieces_of_fair_evidence: true,
            component_values:,
            component_names:,
            identity_proofing: true,
            phishing_resistant: true,
            component_separator: '.',
          },
        }
      end

      it 'includes the sp_request' do
        expect(ahoy).to receive(:track)
          .with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end
  end

  shared_context '#sp_request_attributes[acr_values]' do
    let(:acr_values) { [] }
    let(:sp_request) { {} }
    let(:session) do
      {
        sp: {
          acr_values: acr_values.join(' '),
        },
      }
    end
    let(:expected_attributes) do
      {
        sp_request: {
          component_separator: ' ',
          component_names: acr_values,
          component_values: acr_values.map do |v|
            v.sub("#{Saml::Idp::Constants::LEGACY_ACR_PREFIX}/", '')
          end.index_with(true),
          **sp_request,
        },
      }
    end

    shared_examples 'track event with :sp_request' do
      it 'then #sp_request_attributes() matches :sp_request' do
        expect(analytics.sp_request_attributes).to match(expected_attributes)
      end

      it 'then includes :sp_request in the event' do
        expect(ahoy).to receive(:track)
          .with('Trackable Event', hash_including(expected_attributes))

        analytics.track_event('Trackable Event')
      end
    end
  end

  context 'when acr_values are saved in the session' do
    include_context '#sp_request_attributes[acr_values]'

    shared_examples 'using acrs for all user scenarios' do |acr_values_list|
      let(:acr_values) { acr_values_list }

      context "using #{acr_values_list}" do
        context 'when the user has not been identity verified' do
          let(:current_user) { build(:user, :fully_registered) }

          include_examples 'track event with :sp_request'
        end

        context 'when the identity verified user has not proofed with facial match' do
          let(:current_user) { build(:user, :proofed) }

          include_examples 'track event with :sp_request'
        end

        context 'when the identity verified user has proofed with facial match' do
          let(:current_user) { build(:user, :proofed_with_selfie) }

          include_examples 'track event with :sp_request'
        end
      end
    end

    context 'and does not require any identity proofing' do
      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL_AUTH_ONLY_ACR]
      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF]
    end

    context 'and selects any variant of identity proofing' do
      let(:sp_request) do
        {
          aal2: true,
          identity_proofing: true,
        }
      end

      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL_VERIFIED_ACR]
      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF]
      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF]
    end

    context 'and selects required facial match identity proofing' do
      let(:sp_request) do
        {
          aal2: true,
          facial_match: true,
          two_pieces_of_fair_evidence: true,
          identity_proofing: true,
        }
      end

      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR]

      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF]
    end

    context 'and selects optional facial match identity proofing' do
      shared_examples 'with user scenarios' do |acr_values_list|
        context "using #{acr_values_list}" do
          let(:acr_values) { acr_values_list }

          context 'when the user has not been identity verified' do
            let(:sp_request) do
              {
                aal2: true,
                facial_match: true,
                two_pieces_of_fair_evidence: true,
                identity_proofing: true,
              }
            end
            let(:current_user) { build(:user, :fully_registered) }

            include_examples 'track event with :sp_request'
          end

          context 'when the identity verified user has not proofed with facial match' do
            let(:current_user) { build(:user, :proofed) }
            let(:sp_request) do
              {
                aal2: true,
                identity_proofing: true,
              }
            end

            include_examples 'track event with :sp_request'
          end

          context 'when the identity verified user has proofed with facial match' do
            let(:sp_request) do
              {
                aal2: true,
                facial_match: true,
                two_pieces_of_fair_evidence: true,
                identity_proofing: true,
              }
            end
            let(:current_user) { build(:user, :proofed_with_selfie) }

            include_examples 'track event with :sp_request'
          end
        end
      end

      include_examples 'with user scenarios',
                       [Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR]
      include_examples 'with user scenarios',
                       [Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF]
    end

    context 'and selects the IALMax step-up flow' do
      let(:sp_request) do
        {
          aal2: true,
          ialmax: true,
        }
      end

      include_examples 'using acrs for all user scenarios',
                       [Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF]
    end
  end

  context 'with an SP request_url saved in the session' do
    include_context '#sp_request_attributes[acr_values]'
    let(:acr_values) { [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF] }
    let(:request_url) { nil }
    let(:session) do
      {
        sp: {
          acr_values: acr_values.join(' '),
          request_url:,
        }.compact,
      }
    end

    context 'no request_url' do
      include_examples 'track event with :sp_request'
    end

    context 'a request_url without login_gov_app_differentiator ' do
      let(:request_url) { 'http://localhost:3000/openid_connect/authorize?whatever=something_else' }

      include_examples 'track event with :sp_request'
    end

    context 'a request_url with login_gov_app_differentiator ' do
      let(:request_url) { 'http://localhost:3000/openid_connect/authorize?login_gov_app_differentiator=NY' }
      let(:sp_request) do
        {
          app_differentiator: 'NY',
        }
      end

      include_examples 'track event with :sp_request'
    end
  end
end
