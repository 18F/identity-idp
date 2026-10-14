require 'rails_helper'

RSpec.describe ServiceProviderRequestProxy do
  before do
    ServiceProviderRequestProxy.flush
  end

  describe '.from_uuid' do
    context 'when the record exists' do
      it 'returns the record matching the uuid' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com', ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        )
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end
    end

    context 'when the record carries requested delegation scopes' do
      it 'round-trips them through Redis as strings' do
        ServiceProviderRequestProxy.create(
          uuid: '456', issuer: 'foo', url: 'http://bar.com',
          requested_delegation_scopes: %w[housing_records retirement_benefits]
        )
        expect(ServiceProviderRequestProxy.from_uuid('456').requested_delegation_scopes)
          .to eq(%w[housing_records retirement_benefits])
      end
    end

    context 'when delegated access is disabled' do
      before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false) }

      it 'preserves the Redis shape for an ordinary request' do
        attributes = { uuid: 'legacy',
                       issuer: 'foo',
                       url: 'https://example.com',
                       requested_attributes: ['email'],
                       acr_values: 'old-context' }
        ServiceProviderRequestProxy.create(**attributes, requested_delegation_scopes: [])
        stored = REDIS_POOL.with { |client| client.get(described_class.key('legacy')) }
        expect(JSON.parse(stored, symbolize_names: true)).to eq(attributes.except(:uuid))
      end

      it 'retains delegation state that was already saved before rollback' do
        ServiceProviderRequestProxy.create(
          uuid: 'existing', issuer: 'foo', requested_delegation_scopes: ['housing_records'],
        )
        ServiceProviderRequestProxy.find_or_create_by(uuid: 'existing') { raise 'already saved' }
        expect(ServiceProviderRequestProxy.from_uuid('existing').requested_delegation_scopes)
          .to eq(['housing_records'])
      end
    end

    context 'when an authorization records its DPoP policy' do
      it 'preserves a positive binding marker through Redis' do
        described_class.create(uuid: 'bound', issuer: 'foo', dpop_binding_required: true)
        expect(described_class.from_uuid('bound').dpop_binding_required).to eq(true)
      end

      it 'does not add a binding marker to legacy records' do
        described_class.create(uuid: 'unbound', issuer: 'foo', dpop_binding_required: false)
        stored = REDIS_POOL.with { |client| client.get(described_class.key('unbound')) }
        expect(JSON.parse(stored)).not_to have_key('dpop_binding_required')
        expect(described_class.from_uuid('unbound').dpop_binding_required).to be_nil
      end
    end

    context 'when the record does not exist' do
      it 'returns an instance of NullServiceProviderRequest' do
        expect(ServiceProviderRequestProxy.from_uuid('123'))
          .to be_an_instance_of NullServiceProviderRequest
      end
    end

    context 'bad input' do
      it 'handles a null byte in the uuid' do
        expect(ServiceProviderRequestProxy.from_uuid("\0"))
          .to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles nil' do
        expect(ServiceProviderRequestProxy.from_uuid(nil))
          .to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles empty string' do
        expect(ServiceProviderRequestProxy.from_uuid(''))
          .to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles hashes' do
        expect(ServiceProviderRequestProxy.from_uuid({}))
          .to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles arrays' do
        expect(ServiceProviderRequestProxy.from_uuid([]))
          .to be_an_instance_of NullServiceProviderRequest
      end
    end
  end
end
