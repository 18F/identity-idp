require 'rails_helper'

describe IdentityDecorator do
  include ActionView::Helpers::TagHelper

  describe '#return_to_sp_url' do
    let(:user) { create(:user) }
    let(:service_provider) { 'http://localhost:3000' }
    let(:identity) { create(:identity, :active, user: user, service_provider: service_provider) }

    subject { IdentityDecorator.new(identity) }

    context 'for an sp with a return URL' do
      it 'returns the return url for the sp' do
        return_to_sp_url = ServiceProvider.from_issuer(service_provider).return_to_sp_url
        expect(subject.return_to_sp_url).to eq(return_to_sp_url)
      end
    end

    context 'for an sp without a return URL' do
      let(:service_provider) { 'https://rp2.serviceprovider.com/auth/saml/metadata' }

      it 'returns nil' do
        expect(subject.return_to_sp_url).to eq(nil)
      end
    end
  end

  describe '#failure_to_proof_url' do
    let(:user) { create(:user) }
    let(:service_provider) { 'https://rp1.serviceprovider.com/auth/saml/metadata' }
    let(:identity) { create(:identity, :active, user: user, service_provider: service_provider) }

    subject { IdentityDecorator.new(identity) }

    context 'for an sp with a failure to proof url' do
      it 'returns the failure_to_proof_url for the sp' do
        failure_to_proof_url = ServiceProvider.from_issuer(service_provider).failure_to_proof_url
        expect(subject.failure_to_proof_url).to eq(failure_to_proof_url)
      end
    end

    context 'for an sp without a failure to proof URL' do
      let(:service_provider) { 'http://localhost:3000' }

      it 'returns nil' do
        expect(subject.failure_to_proof_url).to eq(nil)
      end
    end
  end
end
