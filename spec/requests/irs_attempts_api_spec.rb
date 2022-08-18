require 'rails_helper'

RSpec.describe 'IRS attempts API' do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
    events_to_acknowledge
    events_to_render
  end

  let(:events_to_acknowledge) do
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
  let(:events_to_render) do
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

  it 'allows events to be acknowledged and renders new events' do
    auth_token = IdentityConfig.store.irs_attempt_api_auth_tokens.first
    request_body = {
      ack: events_to_acknowledge.map(&:first),
    }
    request_headers = {
      Authorization: "Bearer #{auth_token}",
    }

    post '/api/irs_attempts_api/security_events', params: request_body, headers: request_headers

    expect(response.status).to eq(200)

    expected_response_body = {
      'sets' => events_to_render.to_h,
    }
    expect(JSON.parse(response.body)).to eq(expected_response_body)
  end
end
