require 'rails_helper'

RSpec.describe Api::IrsAttemptsApiController do
  before do
    stub_analytics

    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)

    existing_events

    request.headers['Authorization'] =
      "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
  end

  let(:auth_token) do
    IdentityConfig.store.irs_attempt_api_auth_tokens.first
  end
  let(:existing_events) do
    3.times.map do
      event = IrsAttemptsApi::AttemptEvent.new(
        event_type: :test_event,
        session_id: 'test-session-id',
        occurred_at: Time.zone.now,
        event_metadata: {},
      )
      jti = event.jti
      jwe = event.to_jwe
      IrsAttemptsApi::RedisClient.new.write_event(jti: jti, jwe: jwe)
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
        post :create, params: {}

        expect(response.status).to eq(200)
      end
    end

    it 'renders a 404 if disabled' do
      allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)

      post :create, params: {}

      expect(response.status).to eq(404)
    end

    it 'authenticates the client' do
      request.headers['Authorization'] = auth_token # Missing Bearer prefix

      post :create, params: {}

      expect(response.status).to eq(401)

      request.headers['Authorization'] = 'garbage-fake-token-nobody-likes'

      post :create, params: {}

      expect(response.status).to eq(401)
    end

    it 'renders new events' do
      post :create, params: {}

      expect(response).to be_ok

      expected_response = {
        'sets' => existing_events.to_h,
      }
      expect(JSON.parse(response.body)).to eq(expected_response)
      expect(@analytics).to have_logged_event(
        'IRS Attempt API: Events submitted',
        rendered_event_count: 3,
        set_errors: nil,
      )
    end

    it 'logs errors from the client' do
      set_errors = { abc123: { description: 'it is b0rken' } }

      post :create, params: { setErrs: set_errors }

      expect(response).to be_ok
      expect(@analytics).to have_logged_event(
        'IRS Attempt API: Events submitted',
        rendered_event_count: 3,
        set_errors: set_errors.to_json,
      )
    end

    it 'respects the maxEvents param' do
      post :create, params: { maxEvents: 2 }

      expect(response).to be_ok
      expect(JSON.parse(response.body)['sets'].keys.length).to eq(2)
    end

    it 'does not render more than the configured maximum event allowance' do
      allow(IdentityConfig.store).to receive(:irs_attempt_api_event_count_max).and_return(2)

      post :create, params: { maxEvents: 5 }

      expect(response).to be_ok
      expect(JSON.parse(response.body)['sets'].keys.length).to eq(2)
    end
  end
end
