require 'rails_helper'

RSpec.describe Api::IrsAttemptsApiController do
  before do
    stub_analytics

    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)

    existing_events

    request.headers['Authorization'] =
      "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
  end
  let(:time) { Time.new(2022, 1, 1, 0, 0, 0, 'Z') }

  let(:auth_token) do
    IdentityConfig.store.irs_attempt_api_auth_tokens.first
  end
  let(:existing_events) do
    3.times.map do
      event = IrsAttemptsApi::AttemptEvent.new(
        event_type: :test_event,
        session_id: 'test-session-id',
        occurred_at: time,
        event_metadata: {},
      )
      jti = event.jti
      jwe = event.to_jwe
      IrsAttemptsApi::RedisClient.new.write_event(jti: jti, jwe: jwe, timestamp: event.occurred_at)
      [jti, jwe]
    end
  end
  let(:existing_event_jtis) { existing_events.map(&:first) }

  describe '#create' do
    context 'with CSRF protection enabled' do
      around do |ex|
        ActionController::Base.allow_forgery_protection = true
        ex.run
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it 'allows authentication without error' do
        request.headers['Authorization'] =
          "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
        post :create, params: { timestamp: time.iso8601 }

        expect(response.status).to eq(200)
      end
    end

    it 'renders a 404 if disabled' do
      allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(404)
    end

    it 'returns an error without required timestamp parameter' do
      post :create, params: {}
      expect(response.status).to eq 422
    end

    it 'returns an error with empty timestamp parameter' do
      post :create, params: { timestamp: '' }
      expect(response.status).to eq 422
    end

    it 'returns an error with invalid timestamp parameter' do
      post :create, params: { timestamp: 'abc' }
      expect(response.status).to eq 422
    end

    it 'authenticates the client' do
      request.headers['Authorization'] = auth_token # Missing Bearer prefix

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(401)

      request.headers['Authorization'] = 'garbage-fake-token-nobody-likes'

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(401)
    end

    it 'renders new events' do
      post :create, params: { timestamp: time.iso8601 }

      expect(response).to be_ok

      expected_response = {
        'sets' => existing_events.to_h,
      }
      expect(JSON.parse(response.body)).to eq(expected_response)
      expect(@analytics).to have_logged_event(
        'IRS Attempt API: Events submitted',
        rendered_event_count: 3,
        success: true,
        timestamp: time.iso8601,
      )
    end
  end
end
