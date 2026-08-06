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

    it 'uses no_provider as the issuer when sp is nil' do
      redis_wrapper = instance_double(FraudOps::RedisClient)
      allow(FraudOps::RedisClient).to receive(:new).and_return(redis_wrapper)
      allow(redis_wrapper).to receive(:write_event) do |**args|
        decrypted_event = JWE.decrypt(args[:jwe], fraud_ops_private_key)
        expect(JSON.parse(decrypted_event)['aud']).to eq('no_provider')
      end

      nil_sp_tracker = FraudOps::Tracker.new(
        request: request,
        user: user,
        sp: nil,
        cookie_device_uuid: cookie_device_uuid,
      )

      nil_sp_tracker.login_email_and_password_auth(email: user.email, success: true)

      expect(redis_wrapper).to have_received(:write_event)
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

  describe 'agency_uuid' do
    let(:redis_wrapper) { instance_double(FraudOps::RedisClient) }

    before do
      allow(FraudOps::RedisClient).to receive(:new).and_return(redis_wrapper)
      allow(redis_wrapper).to receive(:write_event)
    end

    def tracked_agency_uuid
      tracker.login_email_and_password_auth(email: user.email, success: true)

      expect(redis_wrapper).to have_received(:write_event) do |**args|
        payload = JSON.parse(JWE.decrypt(args[:jwe], fraud_ops_private_key))
        return payload.dig('events').values.first['agency_uuid']
      end
    end

    it 'creates and includes the AgencyIdentity uuid in the event' do
      expect do
        expect(tracked_agency_uuid).to be_present
      end.to change(AgencyIdentity, :count).by(1)
    end

    it 'includes the existing AgencyIdentity uuid in the event' do
      agency_identity = AgencyIdentityLinker.for(
        user: user, service_provider: sp, skip_create: false,
      )

      expect(tracked_agency_uuid).to eq(agency_identity.uuid)
    end

    it 'falls back to a lookup when creation races with a duplicate' do
      agency_identity = AgencyIdentityLinker.for(
        user: user, service_provider: sp, skip_create: false,
      )

      raised = false
      allow(AgencyIdentityLinker).to receive(:for).and_wrap_original do |original, **kwargs|
        next original.call(**kwargs) if raised || kwargs[:skip_create]

        raised = true
        raise ActiveRecord::RecordNotUnique
      end

      expect(tracked_agency_uuid).to eq(agency_identity.uuid)
    end

    it 'sends a nil agency_uuid when the fallback lookup returns nil' do
      allow(AgencyIdentityLinker).to receive(:for).with(
        user: user, service_provider: sp, skip_create: false,
      ).and_raise(ActiveRecord::RecordNotUnique)
      allow(AgencyIdentityLinker).to receive(:for).with(
        user: user, service_provider: sp, skip_create: true,
      ).and_return(nil)

      expect(tracked_agency_uuid).to be_nil
    end
  end

  describe 'error handling' do
    it 'returns nil and logs a warning when an error occurs' do
      allow(IdentityConfig.store).to receive(:fraud_ops_public_key).and_return('')

      expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(OpenSSL::PKey::RSAError))
      expect(Rails.logger).to receive(:warn).with(
        include('"event":"fraud_ops_tracker_error"'),
      )

      result = tracker.login_email_and_password_auth(email: user.email, success: true)

      expect(result).to be_nil
    end

    it 'returns nil and logs a warning when Redis is unavailable' do
      redis_wrapper = instance_double(FraudOps::RedisClient)
      allow(FraudOps::RedisClient).to receive(:new).and_return(redis_wrapper)
      allow(redis_wrapper).to receive(:write_event).and_raise(Redis::CannotConnectError)

      expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(Redis::CannotConnectError))
      expect(Rails.logger).to receive(:warn).with(
        include('"event":"fraud_ops_tracker_error"'),
      )

      result = tracker.login_email_and_password_auth(email: user.email, success: true)

      expect(result).to be_nil
    end
  end
end
