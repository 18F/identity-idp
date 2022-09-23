require 'rails_helper'

RSpec.describe IrsAttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).
      and_return(irs_attempt_api_enabled)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_payload_size_logging_enabled).
      and_return(irs_attempt_api_payload_size_logging_enabled)
    allow(request).to receive(:user_agent).and_return('example/1.0')
    allow(request).to receive(:remote_ip).and_return('192.0.2.1')
    allow(request).to receive(:headers).and_return(
      { 'CloudFront-Viewer-Address' => '192.0.2.1:1234' },
    )
  end

  let(:irs_attempt_api_enabled) { true }
  let(:irs_attempt_api_payload_size_logging_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:service_provider) { create(:service_provider) }
  let(:cookie_device_uuid) { 'device_id' }
  let(:sp_request_uri) { 'https://example.com/auth_page' }
  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new }

  subject do
    described_class.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: service_provider,
      cookie_device_uuid: cookie_device_uuid,
      sp_request_uri: sp_request_uri,
      enabled_for_session: enabled_for_session,
      analytics: analytics,
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

        events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

        expect(events.values.length).to eq(1)
      end
    end

    it 'does not store events in plaintext in redis' do
      freeze_time do
        subject.track_event(:event, first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name])

        events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

        expect(events.keys.first).to_not include('first_name')
        expect(events.values.first).to_not include(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
      end
    end

    context 'without a service provider' do
      let(:service_provider) { nil }

      it 'still logs metadata about the event' do
        expect(analytics).to receive(:irs_attempts_api_event_metadata).with(
          event_type: :test_event,
          unencrypted_payload_num_bytes: kind_of(Integer),
          recorded: true,
        )

        event = subject.track_event(:test_event, foo: :bar)

        expect(event.payload[:events].first.last[:user_uuid]).
          to eq(nil), 'has a nil user_uuid because there can be no pairwise uuid for no agency'
      end
    end

    context 'the current session is not an IRS attempt API session' do
      let(:enabled_for_session) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

          expect(events.values.length).to eq(0)
        end
      end

      it 'still logs metadata about the event' do
        expect(analytics).to receive(:irs_attempts_api_event_metadata).with(
          event_type: :test_event,
          unencrypted_payload_num_bytes: kind_of(Integer),
          recorded: false,
        )

        subject.track_event(:test_event, foo: :bar)
      end
    end

    context 'the IRS attempts API is not enabled' do
      let(:irs_attempt_api_enabled) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

          expect(events.values.length).to eq(0)
        end
      end

      it 'still logs metadata about the event' do
        expect(analytics).to receive(:irs_attempts_api_event_metadata).with(
          event_type: :test_event,
          unencrypted_payload_num_bytes: kind_of(Integer),
          recorded: false,
        )

        subject.track_event(:test_event, foo: :bar)
      end
    end

    context 'metadata logging is disabled' do
      let(:irs_attempt_api_payload_size_logging_enabled) { false }

      it 'does not log metadata about the event' do
        expect(analytics).to_not receive(:irs_attempts_api_event_metadata)

        subject.track_event(:test_event, foo: :bar)
      end
    end
  end

  describe '#parse_failure_reason' do
    let(:mock_error_message) { 'failure_reason_from_error' }
    let(:mock_error_details) { [{ mock_error: 'failure_reason_from_error_details' }] }

    it 'parses failure_reason from error_details' do
      test_failure_reason = subject.parse_failure_reason(
        { errors: mock_error_message,
          error_details: mock_error_details },
      )

      expect(test_failure_reason).to eq(mock_error_details)
    end

    it 'parses failure_reason from errors when no error_details present' do
      class MockFailureReason
        def errors
          'failure_reason_from_error'
        end

        def to_h
          {}
        end
      end

      test_failure_reason = subject.parse_failure_reason(MockFailureReason.new)

      expect(test_failure_reason).to eq(mock_error_message)
    end
  end
end
