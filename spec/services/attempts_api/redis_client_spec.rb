require 'rails_helper'

RSpec.describe AttemptsApi::RedisClient do
  let(:attempts_api_private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:attempts_api_public_key) { attempts_api_private_key.public_key }
  let(:issuer) { 'test' }

  describe '#write_event' do
    it 'writes the attempt data to redis with the event key as the key' do
      freeze_time do
        now = Time.zone.now
        event = AttemptsApi::AttemptEvent.new(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.zone.now,
          event_metadata: {
            first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
          },
        )
        event_key = event.jti
        jwe = event.to_jwe(issuer: issuer, public_key: attempts_api_public_key)

        subject.write_event(event_key: event_key, jwe: jwe, timestamp: now, issuer: issuer)

        result = subject.read_events(issuer: issuer)
        expect(result[event_key]).to eq(jwe)
      end
    end
  end

  describe '#read_events' do
    it 'reads the event events from redis' do
      freeze_time do
        now = Time.zone.now
        events = {}
        3.times do
          event = AttemptsApi::AttemptEvent.new(
            event_type: 'test_event',
            session_id: 'test-session-id',
            occurred_at: now,
            event_metadata: {
              first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
            },
          )
          event_key = event.jti
          jwe = event.to_jwe(issuer: issuer, public_key: attempts_api_public_key)
          events[event_key] = jwe
        end
        events.each do |event_key, jwe|
          subject.write_event(event_key: event_key, jwe: jwe, timestamp: now, issuer: issuer)
        end

        result = subject.read_events(issuer:)

        expect(result).to eq(events)
      end
    end

    context 'when events are in different buckets' do
      let(:events) { {} }

      before do
        now = Time.zone.now
        3.times do |n|
          event = AttemptsApi::AttemptEvent.new(
            event_type: 'test_event',
            session_id: 'test-session-id',
            occurred_at: now - n.hours,
            event_metadata: {
              first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
            },
          )
          jwe = event.to_jwe(issuer:, public_key: attempts_api_public_key)
          subject.write_event(
            event_key: event.jti, jwe:, timestamp: event.occurred_at, issuer:,
          )
          events[event.jti] = jwe
        end
      end

      it 'returns all the events' do
        expect(subject.read_events(issuer:)).to eq(events)
      end

      context 'when there is a batch_size limit' do
        it 'returns the older events first' do
          expect(subject.read_events(issuer:, batch_size: 2).keys).not_to include(events.keys.first)
        end
      end
    end
  end

  describe '#delete_events' do
    it 'deletes the events from redis' do
      time1 = Time.new(2022, 1, 1, 1, 0, 0, 'Z')
      time2 = Time.new(2022, 1, 1, 2, 0, 0, 'Z')
      event1 = AttemptsApi::AttemptEvent.new(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: time1,
        event_metadata: {
          first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
        },
      )
      event2 = AttemptsApi::AttemptEvent.new(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: time2,
        event_metadata: {
          first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
        },
      )
      jwe1 = event1.to_jwe(issuer: issuer, public_key: attempts_api_public_key)
      jwe2 = event2.to_jwe(issuer: issuer, public_key: attempts_api_public_key)

      subject.write_event(
        event_key: event1.jti, jwe: jwe1, timestamp: event1.occurred_at, issuer: issuer,
      )
      subject.write_event(
        event_key: event2.jti, jwe: jwe2, timestamp: event2.occurred_at, issuer: issuer,
      )

      deleted_events_count = subject.delete_events(issuer:, keys: [event1.jti])
      expect(subject.read_events(issuer:)).to eq({ event2.jti => jwe2 })
      expect(deleted_events_count).to eq(1)
    end
  end
end
