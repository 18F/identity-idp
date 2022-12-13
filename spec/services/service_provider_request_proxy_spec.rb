require 'rails_helper'

describe ServiceProviderRequestProxy do
  before do
    ServiceProviderRequestProxy.flush
  end

  describe '.from_uuid' do
    context 'when the record exists' do
      it 'returns the record matching the uuid' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com',
          ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end

      it 'both loa1 and ial1 values return the same thing' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com',
          ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )

        expect(sp_request.loa).to eq(sp_request.ial)
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end

      it 'both loa3 and ial2 values return the same thing' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com',
          ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        )

        expect(sp_request.loa).to eq(sp_request.ial)
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end
    end

    context 'when the record does not exist' do
      it 'returns an instance of NullServiceProviderRequest' do
        expect(ServiceProviderRequestProxy.from_uuid('123')).
          to be_an_instance_of NullServiceProviderRequest
      end
    end

    context 'bad input' do
      it 'handles a null byte in the uuid' do
        expect(ServiceProviderRequestProxy.from_uuid("\0")).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles nil' do
        expect(ServiceProviderRequestProxy.from_uuid(nil)).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles empty string' do
        expect(ServiceProviderRequestProxy.from_uuid('')).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles hashes' do
        expect(ServiceProviderRequestProxy.from_uuid({})).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'handles arrays' do
        expect(ServiceProviderRequestProxy.from_uuid([])).
          to be_an_instance_of NullServiceProviderRequest
      end
    end
  end
end
