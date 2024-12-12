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
      primary_key_from_response, secondary_key_from_response = json[:keys].map do |key|
        JWT::JWK.import(key).public_key
      end

      primary_public_key = Rails.application.config.oidc_public_key
      expect(primary_key_from_response.to_pem).to eq(primary_public_key.to_pem)

      secondary_public_key = Rails.application.config.oidc_public_key_queue.last
      expect(secondary_key_from_response.to_pem).to eq(secondary_public_key.to_pem)
    end
  end
end
