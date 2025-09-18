require 'rails_helper'

RSpec.describe FraudOps::RedisClient do
  subject(:redis_client) { FraudOps::RedisClient.new }

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_event_ttl_seconds).and_return(604800)

    REDIS_FRAUD_OPS_POOL.with do |client|
      client.keys('fraud-ops-events:*').each { |key| client.del(key) }
    end
  end

  describe '#write_event' do
    it 'writes a JWE token to Redis with expiration' do
      event_key = SecureRandom.uuid
      jwe_token = 'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZHQ00ifQ.test-jwe-token'
      timestamp = Time.zone.now

      redis_client.write_event(
        event_key: event_key,
        jwe: jwe_token,
        timestamp: timestamp,
      )

      REDIS_FRAUD_OPS_POOL.with do |client|
        five_minute_key = "fraud-ops-events:#{timestamp.in_time_zone('UTC').change(
          min: (timestamp.min / 5) * 5,
          sec: 0,
        ).iso8601}"
        stored_data = client.hget(five_minute_key, event_key)
        expect(stored_data).to eq(jwe_token)

        ttl = client.ttl(five_minute_key)
        expect(ttl).to be > 0
        expect(ttl).to be <= 604800
      end
    end
  end
end
