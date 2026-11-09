require 'rails_helper'

RSpec.describe OpenidConnectTokenRevocationForm do
  subject(:form) { described_class.new(client_id:, token:, token_type_hint:) }

  let(:actor) { create(:service_provider, :active) }
  let(:client_id) { actor.issuer }
  let(:token_type_hint) { 'refresh_token' }
  let(:family_id) { SecureRandom.uuid }
  let!(:used) do
    create(
      :token_exchange_refresh_token, family_id:, actor_issuer: actor.issuer,
                                     used_at: Time.zone.now
    )
  end
  let!(:current) do
    create(
      :token_exchange_refresh_token, family_id:, actor_issuer: actor.issuer,
                                     token: 'current-token'
    )
  end
  let(:token) { 'current-token' }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
      .and_return([actor.issuer])
  end

  it 'revokes the whole family of a refresh token issued to the client' do
    expect(form.submit.success?).to eq(true)
    expect(form.submit.extra).to include(revoked: true, refresh_token_family_id: family_id)
    expect(form.response).to eq({})
    expect(form.http_status).to eq(:ok)
    expect([used.reload, current.reload].map(&:revocation_reason).uniq).to eq(['revoked_by_client'])
  end

  context 'with any hint, or none' do
    let(:token_type_hint) { nil }

    it 'still looks for a refresh token' do
      expect(form.submit.extra[:revoked]).to eq(true)
    end
  end

  context 'with an unknown token' do
    let(:token) { 'unknown' }

    it 'succeeds without revoking anything' do
      expect(form.submit.success?).to eq(true)
      expect(form.submit.extra[:revoked]).to eq(false)
      expect(current.reload).not_to be_revoked
    end
  end

  context 'with a refresh token issued to another actor' do
    let(:other_actor) { create(:service_provider, :active) }
    let(:client_id) { other_actor.issuer }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
        .and_return([actor.issuer, other_actor.issuer])
    end

    it 'succeeds without revoking it' do
      expect(form.submit.success?).to eq(true)
      expect(current.reload).not_to be_revoked
    end
  end

  context 'with a client that is not an actor' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers).and_return([])
    end

    it 'fails with invalid_client and a 401' do
      expect(form.response).to eq(error: 'invalid_client')
      expect(form.http_status).to eq(:unauthorized)
      expect(current.reload).not_to be_revoked
    end
  end

  context 'without a token' do
    let(:token) { nil }

    it 'fails with invalid_request' do
      expect(form.response).to eq(error: 'invalid_request')
      expect(form.http_status).to eq(:bad_request)
    end
  end
end
