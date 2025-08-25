require 'rails_helper'

RSpec.describe AttemptsApiCertsPresenter do
  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  subject(:presenter) { described_class.new }

  describe '#certs' do
    describe 'when attempts signing is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:attempts_api_signing_enabled).and_return(true)
      end

      describe 'when the attempts signing key is present' do
        before do
          allow(IdentityConfig.store).to receive(:attempts_api_signing_key).and_return(
            signing_key.to_pem,
          )
        end
        it 'renders the attempts api signing key as a JWK set' do
          json = presenter.certs

          expect(json[:keys].size).to eq(1)
          expect(json[:keys].first[:alg]).to eq 'ES256'
          expect(json[:keys].first[:use]).to eq 'sig'
        end
      end

      describe 'when the attempts signing key is not present' do
        it 'raises a SigningKeyError' do
          expect { presenter.certs }.to raise_error(
            AttemptsApi::AttemptEvent::SigningKey::SigningKeyError,
            'Attempts API signing key is not configured',
          )
        end
      end
    end

    describe 'when attempts signing is not enabled' do
      it 'renders an empty JWK set' do
        json = presenter.certs

        expect(json[:keys]).to eq [{}]
      end
    end
  end
end
