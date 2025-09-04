require 'rails_helper'

RSpec.describe SecuredDataApiCertsPresenter do
  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  subject(:presenter) { described_class.new }

  describe '#certs' do
    describe 'when secured data signing is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:secured_data_api_signing_enabled).and_return(true)
      end

      describe 'when the secured data signing key is present' do
        before do
          allow(IdentityConfig.store).to receive(:secured_data_api_signing_key).and_return(
            signing_key.to_pem,
          )
        end
        it 'renders the secured data api signing key as a JWK set' do
          json = presenter.certs

          expect(json[:keys].size).to eq(1)
          expect(json[:keys].first[:alg]).to eq 'ES256'
          expect(json[:keys].first[:use]).to eq 'sig'
        end
      end

      describe 'when the secured data signing key is not present' do
        it 'raises a SigningKeyError' do
          expect { presenter.certs }.to raise_error(
            SecuredDataApi::SecuredDataEvent::SigningKey::SigningKeyError,
            'Secured Data API signing key is not configured',
          )
        end
      end
    end

    describe 'when secured data signing is not enabled' do
      it 'renders an empty JWK set' do
        json = presenter.certs

        expect(json[:keys]).to eq []
      end
    end
  end
end
