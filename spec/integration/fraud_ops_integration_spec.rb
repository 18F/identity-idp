require 'rails_helper'

RSpec.describe 'Fraud Ops Integration' do
  let(:user) { create(:user) }
  let(:sp) { create(:service_provider) }

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_tracker_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:fraud_ops_encryption_key).and_return(
      Base64.encode64(SecureRandom.random_bytes(32)),
    )
    allow(IdentityConfig.store).to receive(:fraud_ops_event_ttl_seconds).and_return(604800)
    allow(IdentityConfig.store).to receive(:s3_idp_dw_tasks).and_return('login-gov-idp-dw-tasks')
    allow(IdentityConfig.store).to receive(:aws_region).and_return('us-east-1')

    # Clear any existing test data
    REDIS_FRAUD_OPS_POOL.with do |client|
      client.keys('fraud-ops-events:*').each { |key| client.del(key) }
    end
  end

  it 'tracks events in Redis and batches them to S3' do
    redis_client = FraudOpsRedisClient.new
    events_to_return = {
      'event-1' => 'encrypted-event-data-1',
      'event-2' => 'encrypted-event-data-2',
    }

    allow(redis_client).to receive(:read_all_events).and_return(events_to_return)
    allow(redis_client).to receive(:delete_events).and_return(2)
    allow(FraudOpsRedisClient).to receive(:new).and_return(redis_client)

    redis_wrapper = instance_double(FraudOpsRedisClientWrapper)
    allow(FraudOpsRedisClientWrapper).to receive(:new).and_return(redis_wrapper)
    allow(redis_wrapper).to receive(:write_event)

    tracker = FraudOpsTracker.new(
      session_id: SecureRandom.hex(16),
      request: ActionDispatch::TestRequest.create,
      user: user,
      sp: sp,
      cookie_device_uuid: SecureRandom.hex(16),
      sp_redirect_uri: 'https://example.com/redirect',
    )

    tracker.login_email_and_password_auth(success: true)
    tracker.logout_initiated(success: true)

    expect(redis_wrapper).to have_received(:write_event).twice
    s3_client = instance_double(Aws::S3::Client)
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

    uploaded_data = nil
    allow(s3_client).to receive(:put_object) do |args|
      uploaded_data = JSON.parse(args[:body])
    end

    FraudOpsS3BatchJob.new.perform
    expect(s3_client).to have_received(:put_object) do |args|
      expect(args[:bucket]).to eq('login-gov-idp-dw-tasks')
      expect(args[:key]).to match(/fraud-ops-events\/\d{4}\/\d{2}\/\d{2}\/events-\d+-[a-f0-9]+\.json/)
      expect(args[:server_side_encryption]).to eq('AES256')
    end

    expect(uploaded_data['event_count']).to eq(2)
    expect(uploaded_data['events']).to be_an(Array)
    expect(uploaded_data['events'].first['jti']).to eq('event-1')
    expect(uploaded_data['events'].first['encrypted_data']).to eq('encrypted-event-data-1')

    expect(redis_client).to have_received(:delete_events).with(keys: events_to_return.keys)
  end

  it 'works independently of attempts API tracker' do
    redis_wrapper = instance_double(FraudOpsRedisClientWrapper)
    allow(FraudOpsRedisClientWrapper).to receive(:new).and_return(redis_wrapper)
    allow(redis_wrapper).to receive(:write_event)

    tracker = FraudOpsTracker.new(
      session_id: SecureRandom.hex(16),
      request: ActionDispatch::TestRequest.create,
      user: user,
      sp: sp,
      cookie_device_uuid: SecureRandom.hex(16),
      sp_redirect_uri: 'https://example.com/redirect',
    )

    tracker.logout_initiated(success: true)

    expect(redis_wrapper).to have_received(:write_event)
  end
end
