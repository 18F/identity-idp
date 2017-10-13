require 'rails_helper'

describe IdentityDecorator do
  include ActionView::Helpers::TagHelper

  let(:user) { create(:user) }
  let(:service_provider) { 'http://localhost:3000' }
  let(:identity) { create(:identity, :active, user: user, service_provider: service_provider) }

  subject { IdentityDecorator.new(identity) }

  describe '#return_to_sp_url' do
    context 'for an sp without a return URL' do
      context 'for an sp with a return URL' do
        it 'returns the return url for the sp' do
          return_to_sp_url = ServiceProvider.from_issuer(service_provider).return_to_sp_url
          expect(subject.return_to_sp_url).to eq(return_to_sp_url)
        end
      end

      let(:service_provider) { 'https://rp2.serviceprovider.com/auth/saml/metadata' }

      it 'returns nil' do
        expect(subject.return_to_sp_url).to eq(nil)
      end
    end
  end
end
