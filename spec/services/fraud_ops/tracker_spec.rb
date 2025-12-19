require 'rails_helper'

RSpec.describe FraudOps::Tracker do
  let(:user) { create(:user) }
  let(:sp) { create(:service_provider) }
  let(:fraud_ops_private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:fraud_ops_public_key) { fraud_ops_private_key.public_key }
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
    FraudOps::Tracker.new(
      request: request,
      user: user,
      sp: sp,
      cookie_device_uuid: cookie_device_uuid,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_tracker_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:fraud_ops_public_key).and_return(
      fraud_ops_public_key.to_pem,
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

    it 'uses FraudOps::RedisClient for Redis operations' do
      redis_wrapper = instance_double(FraudOps::RedisClient)
      allow(FraudOps::RedisClient).to receive(:new).and_return(redis_wrapper)
      allow(redis_wrapper).to receive(:write_event)

      new_tracker = FraudOps::Tracker.new(
        request: request,
        user: user,
        sp: sp,
        cookie_device_uuid: cookie_device_uuid,
      )

      new_tracker.login_email_and_password_auth(email: user.email, success: true)

      expect(redis_wrapper).to have_received(:write_event)
    end
  end
end
