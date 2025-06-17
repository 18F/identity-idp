require 'rails_helper'

RSpec.describe AttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:attempts_api_enabled)
      .and_return(attempts_api_enabled)
    allow(request).to receive(:user_agent).and_return('example/1.0')
    allow(request).to receive(:remote_ip).and_return('192.0.2.1')
    allow(request).to receive(:cookies).and_return(nil)
    allow(request).to receive(:headers).and_return(
      { 'CloudFront-Viewer-Address' => '192.0.2.1:1234' },
    )
  end

  let(:attempts_api_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:service_provider) { create(:service_provider) }
  let(:cookie_device_uuid) { 'device_id' }
  let(:sp_request_uri) { 'https://example.com/auth_page' }
  let(:user) { create(:user) }

  subject do
    described_class.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: service_provider,
      cookie_device_uuid: cookie_device_uuid,
      sp_request_uri: sp_request_uri,
      enabled_for_session: enabled_for_session,
    )
  end

  describe '#track_event' do
    it 'omit failure reason when success is true' do
      freeze_time do
        event = subject.track_event(:test_event, foo: :bar, success: true, failure_reason: nil)
        expect(event.event_metadata).to_not have_key(:failure_reason)
      end
    end

    it 'omit failure reason when failure_reason is blank' do
      freeze_time do
        event = subject.track_event(:test_event, foo: :bar, failure_reason: nil)
        expect(event.event_metadata).to_not have_key(:failure_reason)
      end
    end

    it 'includes GA cookies' do
      allow(request).to receive(:cookies).and_return(
        {
          '_ga' => 'GA1.ABC',
          '_ga_ABC' => 'GS2.ABC',
          'other_cookie' => 'abc',
        },
      )

      event = subject.track_event(:test_event)
      expect(event.event_metadata).to include(
        {
          google_analytics_cookies: {
            '_ga' => 'GA1.ABC',
            '_ga_ABC' => 'GS2.ABC',
          },
        },
      )
    end

    it 'should not omit failure reason when success is false and failure_reason is not blank' do
      freeze_time do
        event = subject.track_event(
          :test_event, foo: :bar, success: false,
                       failure_reason: { foo: [:bar] }
        )
        expect(event.event_metadata).to have_key(:failure_reason)
        expect(event.event_metadata).to have_key(:success)
      end
    end

    it 'records the event in redis' do
      freeze_time do
        subject.track_event(:test_event, foo: :bar)

        events = AttemptsApi::RedisClient.new.read_events(
          issuer: service_provider.issuer,
        )

        expect(events.values.length).to eq(1)
      end
    end

    it 'does not store events in plaintext in redis' do
      freeze_time do
        subject.track_event(:event, first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name])

        events = AttemptsApi::RedisClient.new.read_events(
          issuer: service_provider.issuer,
        )

        expect(events.keys.first).to_not include('first_name')
        expect(events.values.first).to_not include(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
      end
    end

    context 'with nil user' do
      let(:user) { nil }

      it 'logs nil user_uuid' do
        event = subject.track_event(:test_event)
        expect(event.event_metadata[:user]).to be_nil
      end

      it 'returns the default locale as the language attribute' do
        event = subject.track_event(:test_event)
        expect(event.event_metadata[:language]).to eq('en')
      end
    end

    context 'with AnonymousUser user' do
      let(:user) { AnonymousUser.new }

      it 'logs nil user_uuid' do
        event = subject.track_event(:test_event)
        expect(event.event_metadata[:user]).to be_nil
      end

      it 'returns default locale as the language attribute' do
        event = subject.track_event(:test_event)
        expect(event.event_metadata[:language]).to eq('en')
      end
    end

    context 'user that has a locale selected' do
      before { user.update(email_language: :es) }
      it 'returns that locale as a language attribute in event' do
        event = subject.track_event(:test_event)

        expect(event.event_metadata[:language]).to eq('es')
      end
    end

    context 'user has existing Agency UUID' do
      context 'for event that skips UUID creation' do
        it 'returns Agency UUID in event' do
          identity = create(
            :agency_identity,
            user_id: user.id,
            agency_id: service_provider.agency.id,
          )

          event = subject.track_event(
            AttemptsApi::Tracker::SKIP_AGENCY_UUID_CREATION_EVENT_TYPES.sample,
          )

          expect(event.event_metadata[:user_uuid]).to eq(identity.uuid)
        end
      end

      context 'for event that does not skip UUID creation' do
        it 'returns Agency UUID in event' do
          identity = create(
            :agency_identity,
            user_id: user.id,
            agency_id: service_provider.agency.id,
          )

          event = subject.track_event(
            'my-fake-event',
          )

          expect(event.event_metadata[:user_uuid]).to eq(identity.uuid)
        end
      end
    end

    context 'user does not have existing Agency UUID' do
      context 'for event that skips UUID creation' do
        it 'returns nil UUID in event and does not create identity' do
          event = subject.track_event(
            AttemptsApi::Tracker::SKIP_AGENCY_UUID_CREATION_EVENT_TYPES.sample,
          )

          identity = AgencyIdentity.find_by(
            user_id: user.id,
            agency_id: service_provider.agency.id,
          )
          expect(event.event_metadata[:user_uuid]).to eq(nil)
          expect(identity).to eq(nil)
        end
      end

      context 'for event that does not skip UUID creation' do
        it 'creates new Agency UUID and returns Agency UUID in event' do
          event = subject.track_event(
            'my-fake-event',
          )
          identity = AgencyIdentity.find_by(
            user_id: user.id,
            agency_id: service_provider.agency.id,
          )
          expect(identity).to_not be_nil
          expect(event.event_metadata[:user_uuid]).to eq(identity.uuid)
        end
      end
    end

    context 'the current session is not an attempts API session' do
      let(:enabled_for_session) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = AttemptsApi::RedisClient.new.read_events(
            issuer: service_provider.issuer,
          )

          expect(events.values.length).to eq(0)
        end
      end
    end

    context 'the attempts API is not enabled' do
      let(:attempts_api_enabled) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = AttemptsApi::RedisClient.new.read_events(
            issuer: service_provider.issuer,
          )

          expect(events.values.length).to eq(0)
        end
      end
    end
  end

  describe '#parse_failure_reason' do
    let(:mock_error_message) { 'failure_reason_from_error' }
    let(:mock_error_details) { { mock_error: { failure_reason_from_error_details: true } } }

    it 'parses failure_reason from error_details' do
      test_failure_reason = subject.parse_failure_reason(
        { errors: mock_error_message,
          error_details: mock_error_details },
      )

      expect(test_failure_reason).to eq({ mock_error: [:failure_reason_from_error_details] })
    end

    it 'parses failure_reason from errors when no error_details present' do
      mock_failure_reason = double(
        'MockFailureReason',
        errors: mock_error_message,
        to_h: {},
      )

      test_failure_reason = subject.parse_failure_reason(mock_failure_reason)

      expect(test_failure_reason).to eq(mock_error_message)
    end
  end
end
