require 'rails_helper'

RSpec.describe OpenidConnectCertsPresenter do
  subject(:presenter) { OpenidConnectCertsPresenter.new }

  describe '#certs' do
    it 'renders the server public keys as a JWK set' do
      json = presenter.certs

      expect(json[:keys].size).to eq(2)
      expect(json[:keys].all? { |k| k[:alg] == 'RS256' }).to eq(true)
      expect(json[:keys].all? { |k| k[:use] == 'sig' }).to eq(true)

      # Primary key should be first
      primary_key_from_response = JWT::JWK.import(json[:keys].first).public_key
      primary_public_key = AppArtifacts.store.oidc_primary_public_key

      expect(primary_key_from_response.to_pem).to eq(primary_public_key.to_pem)

      secondary_key_from_response = JWT::JWK.import(json[:keys][1]).public_key
      secondary_public_key = AppArtifacts.store.oidc_secondary_public_key

      expect(secondary_key_from_response.to_pem).to eq(secondary_public_key.to_pem)
    end
  end
end
