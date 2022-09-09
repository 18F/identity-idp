require 'rails_helper'

RSpec.describe Idv::InheritedProofing::Va::Mocks::VaApiClient do
  include_context 'va_api_context'

  let(:subject) { Idv::InheritedProofing::Va::Mocks::VaApiClient.new(auth_code) }

  describe 'valid auth code' do
    it 'makes it valid request' do
      expect(subject.user_attributes).to be_truthy
    end

    it 'returns valid json' do
      expect(subject.user_attributes['Content-Type']).to eq('application/json')
    end

    it 'can be decrypted' do
      response = subject.user_attributes
      payload = JSON.parse(response.body)['data']
      user_attributes = JWE.decrypt(payload, private_key)

      expect(user_attributes).to include('123 Fake St')
    end
  end

  describe 'invalid auth code' do
    let(:auth_code) { 'some_nonsense' }

    it 'returns an error' do
      expect { subject.user_attributes }.to raise_error
    end
  end
end
