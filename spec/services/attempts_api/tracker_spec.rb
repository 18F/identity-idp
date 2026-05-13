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
    allow(request).to receive(:session).and_return({})
  end

  let(:attempts_api_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:service_provider) { create(:service_provider) }
  let(:cookie_device_uuid) { 'device_id' }
  let(:sp_redirect_uri) { 'https://example.com/auth_page' }
  let(:user) { create(:user) }

  subject do
    described_class.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: service_provider,
      cookie_device_uuid: cookie_device_uuid,
      sp_redirect_uri: sp_redirect_uri,
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

      context 'when a user_id is provided' do
        let(:passed_in_user)  { create(:user) }
        it 'looks up the user and logs the user_uuid if found' do
          event = subject.track_event(:test_event, success: true, user_id: passed_in_user.uuid)
          identity = AgencyIdentityLinker.for(
            user: passed_in_user,
            service_provider: service_provider,
            skip_create: false,
          )

          expect(event.event_metadata[:user_uuid]).to eq(identity.uuid)
        end
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

      context 'when a user_id is provided' do
        let(:passed_in_user)  { create(:user) }
        it 'looks up the user and logs the user_uuid if found' do
          event = subject.track_event(:test_event, success: true, user_id: passed_in_user.uuid)
          identity = AgencyIdentityLinker.for(
            user: passed_in_user,
            service_provider: service_provider,
            skip_create: false,
          )

          expect(event.event_metadata[:user_uuid]).to eq(identity.uuid)
        end
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

    context 'when historical_attempts_api_enabled is true' do
      let(:historical_attempts_pii_enabled) { true }
      before do
        allow(IdentityConfig.store).to receive_messages(
          historical_attempts_api_enabled: true,
          historical_attempts_pii_enabled:,
        )
      end

      let(:secure_random_regex_pattern) do
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      end

      context 'with Devise session' do
        let(:mock_session) { { 'warden.user.user.session' => {} } }
        let(:user_session) { mock_session['warden.user.user.session'] }
        let(:agency_uuid) do
          AgencyIdentityLinker.for(user:, service_provider:, skip_create: false).uuid
        end

        before do
          allow(request).to receive(:session).and_return(mock_session)
        end

        context 'when an event prefixed with "idv-" is tracked' do
          it 'populates the session info with that event data' do
            subject.idv_enrollment_complete(reproof: false)

            event_data = user_session['idv/attempts'].first
            expect(event_data['event_metadata']['user_uuid']).to eq(agency_uuid)
            expect(event_data['jti']).to match(secure_random_regex_pattern)
            expect(event_data['event_type']).to eq('idv-enrollment-complete')
          end

          it 'records the event to redis' do
            freeze_time do
              subject.idv_enrollment_complete(reproof: false)

              events = AttemptsApi::RedisClient.new.read_events(
                issuer: service_provider.issuer,
              )

              expect(events.values.length).to eq(1)
            end
          end
        end

        context 'when an event not prefixed with "idv" is tracked' do
          it 'does not populate the event data into the session' do
            subject.user_registration_email_confirmed(success: true, email: 'email@example.com')
            expect(user_session).to eq({})
          end

          it 'records the event to redis' do
            freeze_time do
              subject.user_registration_email_confirmed(success: true, email: 'email@example.com')

              events = AttemptsApi::RedisClient.new.read_events(
                issuer: service_provider.issuer,
              )

              expect(events.values.length).to eq(1)
            end
          end
        end

        context 'both prefixed and not prefixed events are tracked' do
          it 'only populates the event prefixed with idv- in the session' do
            subject.idv_enrollment_complete(reproof: false)
            subject.user_registration_email_confirmed(success: true, email: 'email@example.com')

            expect(user_session['idv/attempts'].count).to be(1)
            event_data = user_session['idv/attempts'].first
            expect(event_data['event_metadata']['user_uuid']).to eq(agency_uuid)
            expect(event_data['jti']).to match(secure_random_regex_pattern)
            expect(event_data['event_type']).to eq('idv-enrollment-complete')
          end

          it 'records both events to redis' do
            freeze_time do
              subject.idv_enrollment_complete(reproof: false)

              subject.user_registration_email_confirmed(
                success: true,
                email: 'email@example.com',
              )

              events = AttemptsApi::RedisClient.new.read_events(
                issuer: service_provider.issuer,
              )

              expect(events.values.length).to eq(2)
            end
          end
        end

        context 'the current session is not an attempts API session' do
          let(:enabled_for_session) { false }

          it 'does not record any events in redis' do
            freeze_time do
              subject.idv_enrollment_complete(reproof: false)

              events = AttemptsApi::RedisClient.new.read_events(
                issuer: service_provider.issuer,
              )

              expect(events.values.length).to eq(0)
            end
          end

          it 'still populates the session info' do
            subject.idv_enrollment_complete(reproof: false)

            event_data = user_session['idv/attempts'].first
            expect(event_data['event_metadata']['user_uuid']).to eq(agency_uuid)
            expect(event_data['jti']).to match(secure_random_regex_pattern)
            expect(event_data['event_type']).to eq('idv-enrollment-complete')
          end
        end

        context 'there is already an event in the session' do
          it 'appends to the existing events' do
            user_session['idv/attempts'] = [
              { 'jti' => 'some-jti',
                'event_metadata' => { 'user_uuid' => user.uuid },
                'event_type' => 'idv-something' },
            ]
            subject.idv_enrollment_complete(reproof: false)

            event_data = user_session['idv/attempts'].first
            expect(event_data['event_metadata']['user_uuid']).to eq(user.uuid)
            expect(event_data['jti']).to match('some-jti')
            expect(event_data['event_type']).to eq('idv-something')

            event_data2 = user_session['idv/attempts'].last
            expect(event_data2['event_metadata']['user_uuid']).to eq(agency_uuid)
            expect(event_data2['jti']).to match(secure_random_regex_pattern)
            expect(event_data2['event_type']).to eq('idv-enrollment-complete')
          end
        end

        context 'when historical_attempts_pii_enabled is false' do
          let(:historical_attempts_pii_enabled) { false }

          it 'does not populate the historical session info' do
            subject.idv_enrollment_complete(reproof: false)
            event_data = user_session['idv/attempts'].first

            expect(event_data['event_metadata']).to eq({ user_uuid: agency_uuid })
            expect(event_data['event_type']).to eq('idv-enrollment-complete')
          end
        end
      end

      it 'does not fail if the request is missing' do
        # This happens, for example, when `SocureDocvResultsJob` runs.
        # We'll come back later and assess if we need to make a ticket to log events from the job.
        subject = described_class.new(
          session_id: nil,
          request: nil,
          user: user,
          sp: service_provider,
          cookie_device_uuid: nil,
          sp_redirect_uri: nil,
          enabled_for_session: true,
        )
        expect { subject.idv_enrollment_complete(reproof: false) }.not_to raise_error
      end
    end

    context 'when historical_attempts_api_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:historical_attempts_api_enabled).and_return(false)
      end

      context 'with Devise session' do
        let(:mock_session) { { 'warden.user.user.session' => {} } }

        it 'records to redis' do
          freeze_time do
            subject.idv_enrollment_complete(reproof: false)

            events = AttemptsApi::RedisClient.new.read_events(
              issuer: service_provider.issuer,
            )

            expect(events.values.length).to eq(1)
          end
        end

        it 'does not populate the historical session info' do
          subject.idv_enrollment_complete(reproof: false)
          expect(mock_session).to eq({ 'warden.user.user.session' => {} })
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

  describe '#self.write_existing_user_events' do
    let(:sp) { service_provider }
    let(:mock_session) { { 'warden.user.user.session' => {} } }
    let(:user_session) { mock_session['warden.user.user.session'] }
    let(:redis_client) { double AttemptsApi::RedisClient }

    before do
      allow(request).to receive(:session).and_return(mock_session)

      allow(IdentityConfig.store).to receive(:historical_attempts_api_enabled).and_return(true)
      subject.idv_enrollment_complete(reproof: false)
      subject.user_registration_email_confirmed(success: true, email: 'email@example.com')
    end

    it 'writes existing user events to redis' do
      expect(AttemptsApi::RedisClient).to receive(:new).and_return(redis_client)
      expect_any_instance_of(AttemptsApi::AttemptEvent).to receive(:to_jwe).and_return('jwe_data')

      event_data = user_session['idv/attempts'].first
      expect(redis_client).to receive(:write_event).with(
        event_key: event_data['jti'],
        jwe: 'jwe_data',
        timestamp: event_data['occurred_at'],
        issuer: sp.issuer,
      )

      described_class.write_existing_user_events(
        sp:,
        historical_attempts: user_session['idv/attempts'],
      )
    end
  end
end
