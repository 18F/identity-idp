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
