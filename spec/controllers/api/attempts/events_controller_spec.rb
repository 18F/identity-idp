require 'rails_helper'

RSpec.describe Api::Attempts::EventsController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }

  before do
    allow(IdentityConfig.store).to receive(:attempts_api_enabled).and_return(enabled)
  end

  describe '#poll' do
    let(:sp) { create(:service_provider) }
    let(:issuer) { sp.issuer }
    let(:acks) do
      [
        'acknowleded-jti-id-1',
        'acknowleded-jti-id-2',
      ]
    end

    let(:payload) do
      {
        maxEvents: '1000',
        acks:,
      }
    end

    let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:public_key) { private_key.public_key }
    let(:redis_client) { AttemptsApi::RedisClient.new }

    let(:token) { 'a-shared-secret' }
    let(:salt) { SecureRandom.hex(32) }
    let(:cost) { IdentityConfig.store.scrypt_cost }

    let(:hashed_token) do
      scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
      SCrypt::Password.new(scrypted).digest
    end

    let(:auth_header) { "Bearer #{issuer} #{token}" }

    before do
      request.headers['Authorization'] = auth_header
      allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
        [{
          issuer: sp.issuer,
          tokens: [{ value: hashed_token, salt: }],
        }],
      )
      allow(AttemptsApi::RedisClient).to receive(:new).and_return redis_client
    end

    let(:action) { post :poll, params: payload }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }

      context 'with a valid authorization header' do
        it 'returns 200 status' do
          expect(action.status).to eq(200)
        end

        context 'with events stored in redis' do
          let(:timestamp) { Time.zone.now }
          let(:event) do
            AttemptsApi::AttemptEvent.new(
              event_type: 'test_event',
              session_id: 'test-session-id',
              occurred_at: Time.zone.now,
              event_metadata: {
                first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
              },
            )
          end
          let(:event_key) { event.jti }
          let(:jwe) { event.to_jwe(issuer:, public_key:) }

          before do
            redis_client.write_event(
              event_key:,
              jwe:,
              timestamp:,
              issuer:,
            )
          end

          it 'returns a json blob including that set' do
            expect(redis_client).to receive(:delete_events).with(
              issuer:,
              keys: [*acks],
            ).and_call_original
            expect(action.body).to eq({ sets: { "#{event_key}": jwe } }.to_json)
          end

          context 'when an event is acknowledged' do
            let(:acks) { [event_key] }

            it 'does not return any acknowledged events' do
              expect(redis_client).to receive(:delete_events).with(
                issuer:,
                keys: [event_key],
              ).and_call_original

              expect(action.body).to eq({ sets: {} }.to_json)
            end
          end

          context 'when there are multiple events' do
            let(:events) { {} }
            before do
              3.times do
                event = AttemptsApi::AttemptEvent.new(
                  event_type: 'test_event',
                  session_id: 'test-session-id',
                  occurred_at: Time.zone.now,
                  event_metadata: {
                    first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
                  },
                )
                event_key = event.jti
                jwe = event.to_jwe(issuer:, public_key:)
                events[event_key] = jwe
              end
              events.each do |event_key, jwe|
                redis_client.write_event(
                  event_key:, jwe:, timestamp: Time.zone.now - 2.hours,
                  issuer:
                )
              end
            end

            it 'returns a json blob including all those events set' do
              sets = events.merge({ event_key => jwe })
              expect(JSON.parse(action.body)).to eq({ 'sets' => sets })
            end

            context 'when the payload includes a maxEvents parameter' do
              let(:payload) do
                {
                  maxEvents: 3,
                  acks:,
                }
              end

              it 'only returns the number of events indicated' do
                expect(JSON.parse(action.body)['sets'].length).to be 3
              end

              it 'returns the oldest events' do
                expect(JSON.parse(action.body)['sets'].keys).to_not include event_key
              end
            end
          end
        end

        context 'with no events in Redis' do
          it 'returns an empty set' do
            expect(redis_client).to receive(:delete_events).and_call_original
            expect(action.body).to eq({ sets: {} }.to_json)
          end
        end
      end

      context 'with an invalid authorization header' do
        context 'with no Authorization header' do
          let(:auth_header) { nil }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'when Authorization header is an empty string' do
          let(:auth_header) { '' }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'without a Bearer token Authorization header' do
          let(:auth_header) { "#{issuer} #{token}" }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'without a valid issuer' do
          context 'an unknown issuer' do
            let(:issuer) { 'random-issuer' }

            it 'returns a 401' do
              expect(action.status).to eq 401
            end
          end
        end

        context 'without a valid token' do
          let(:auth_header) { "Bearer #{issuer}" }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'with a valid but not config token' do
          let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end
      end
    end
  end

  describe 'status' do
    let(:action) { get :status }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }
      it 'returns a 200' do
        expect(action.status).to eq(200)
      end

      it 'returns the disabled status and reason' do
        body = JSON.parse(action.body, symbolize_names: true)
        expect(body[:status]).to eq('disabled')
        expect(body[:reason]).to eq('not_yet_implemented')
      end
    end
  end
end
