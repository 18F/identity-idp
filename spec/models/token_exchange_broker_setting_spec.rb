require 'rails_helper'

RSpec.describe TokenExchangeBrokerSetting do
  let(:user) { create(:user) }
  let(:broker) { 'broker.gov' }
  let(:setting) { described_class.for(user:, broker_issuer: broker) }
  let(:target) do
    create(
      :service_provider, :active, issuer: 'new.gov', delegation_application: true,
                                  allowed_delegation_service_providers: [broker]
    )
  end

  before do
    create(:service_provider, :active, issuer: broker, token_exchange_enabled_sp: true)
    create(:service_provider_identity, user: user, service_provider: broker)
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
  end

  describe '#enable_auto_enroll! / #disable_auto_enroll!' do
    it 'records the first consent time and keeps it across re-enables' do
      first = 2.months.ago.change(usec: 0)
      setting.enable_auto_enroll!(now: first)
      setting.disable_auto_enroll!
      setting.enable_auto_enroll!(now: Time.zone.now)

      expect(setting.auto_enroll_enabled?).to eq(true)
      expect(setting.auto_enroll_granted_at).to eq(first)
    end

    it 'expires after the grant duration' do
      setting.enable_auto_enroll!(now: 13.months.ago)
      expect(setting.auto_enroll_enabled?).to eq(false)
    end
  end

  describe '#auto_enroll!' do
    it 'grants a newly connected, opted-in target stamped at the ORIGINAL consent time' do
      consent = 2.months.ago.change(usec: 0)
      setting.enable_auto_enroll!(now: consent)

      setting.auto_enroll!(target)

      grant = TokenExchangeGrant.find_by(user:, broker_issuer: broker, target_issuer: 'new.gov')
      expect(grant.granted_at).to eq(consent)
      expect(grant.expires_at).to eq(consent + TokenExchangeGrant::GRANT_DURATION)
    end

    it 'does nothing when auto-enrollment is off' do
      setting.auto_enroll!(target)
      expect(TokenExchangeGrant.where(user:)).to be_empty
    end

    it 'does nothing for a target that has not opted in to the broker' do
      setting.enable_auto_enroll!
      target.update!(allowed_delegation_service_providers: ['other-service-provider.gov'])
      setting.auto_enroll!(target)
      expect(TokenExchangeGrant.where(user:)).to be_empty
    end

    it 'does not resurrect a target the user explicitly revoked' do
      setting.enable_auto_enroll!
      TokenExchangeGrant.grant_one!(user:, broker_issuer: broker, target_issuer: 'new.gov')
      TokenExchangeGrant.revoke!(user:, broker_issuer: broker, target_issuer: 'new.gov')

      setting.auto_enroll!(target)

      expect(TokenExchangeGrant.active.where(user:, target_issuer: 'new.gov')).to be_empty
    end

    it 'does nothing once the broker is disconnected from the account' do
      setting.enable_auto_enroll!
      user.identities.where(service_provider: broker).destroy_all
      setting.auto_enroll!(target)
      expect(TokenExchangeGrant.where(user:)).to be_empty
    end
  end
end
