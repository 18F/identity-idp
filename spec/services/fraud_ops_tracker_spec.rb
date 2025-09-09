require 'rails_helper'

RSpec.describe FraudOpsTracker do
  let(:user) { create(:user) }
  let(:sp) { create(:service_provider) }
  let(:request) do
    double(
      'request', user_agent: 'test browser', remote_ip: '192.168.1.1', cookies: {},
                 headers: {}
    )
  end
  let(:session_id) { SecureRandom.hex(16) }
  let(:cookie_device_uuid) { SecureRandom.hex(16) }
  let(:sp_redirect_uri) { 'https://example.com/redirect' }

  subject(:tracker) do
    FraudOpsTracker.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: sp,
      cookie_device_uuid: cookie_device_uuid,
      sp_redirect_uri: sp_redirect_uri,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_tracker_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:fraud_ops_encryption_key).and_return(
      Base64.encode64(SecureRandom.random_bytes(32)),
    )
    allow(IdentityConfig.store).to receive(:fraud_ops_event_ttl_seconds).and_return(604800)
    allow(IdentityConfig.store).to receive(:aws_region).and_return('us-east-1')
  end

  describe 'inheritance and functionality' do
    it 'inherits tracking methods from AttemptsApi::Tracker' do
      expect(tracker).to respond_to(:login_email_and_password_auth)
      expect(tracker).to respond_to(:logout_initiated)
      expect(tracker).to respond_to(:session_timeout)
    end

    it 'uses FraudOpsRedisClientWrapper for Redis operations' do
      redis_wrapper = instance_double(FraudOpsRedisClientWrapper)
      allow(FraudOpsRedisClientWrapper).to receive(:new).and_return(redis_wrapper)
      allow(redis_wrapper).to receive(:write_event)

      new_tracker = FraudOpsTracker.new(
        session_id: SecureRandom.hex(16),
        request: request,
        user: user,
        sp: sp,
        cookie_device_uuid: cookie_device_uuid,
        sp_redirect_uri: sp_redirect_uri,
      )

      new_tracker.login_email_and_password_auth(success: true)

      expect(redis_wrapper).to have_received(:write_event)
    end
  end
end
