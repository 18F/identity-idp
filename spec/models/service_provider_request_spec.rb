require 'rails_helper'

describe ServiceProviderRequest do
  describe '.from_uuid' do
    context 'when the record exists' do
      it 'returns the record matching the uuid' do
        sp_request = ServiceProviderRequest.create(
          uuid: '123', issuer: 'foo', url: 'http://bar.com', loa: '1',
        )

        expect(ServiceProviderRequest.from_uuid('123')).to eq sp_request
      end
    end

    context 'when the record does not exists' do
      it 'returns an instance of NullServiceProviderRequest' do
        expect(ServiceProviderRequest.from_uuid('123')).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'returns an instance of NullServiceProviderRequest when the uuid contains a null byte' do
        expect(ServiceProviderRequest.from_uuid("\0")).
          to be_an_instance_of NullServiceProviderRequest
      end
    end
  end
end
