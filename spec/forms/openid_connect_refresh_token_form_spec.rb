require 'rails_helper'

RSpec.describe OpenidConnectRefreshTokenForm do
  include Rails.application.routes.url_helpers

  subject(:form) { described_class.new(params) }

  let(:actor) { create(:service_provider, :active, pkce: true, certs: []) }
  let(:user) { create(:user) }
  let(:identity) do
    create(
      :service_provider_identity,
      user:,
      service_provider: actor.issuer,
      scope: 'openid token_exchange',
      ial: 1,
    )
  end
  let(:resource) { 'https://records.example.gov' }
  let!(:issued) do
    TokenExchange::RefreshTokenIssuer.issue(
      identity:, actor_return_log_id: 7, resource:, dpop_jkt: dpop_thumbprint,
      authenticated_at: 5.minutes.ago
    )
  end
  let(:refresh_token) { issued.token }
  let(:client_id) { actor.issuer }
  let(:scope) { nil }
  let(:dpop_proof) { build_dpop_proof(http_url: api_openid_connect_token_url) }
  let(:params) do
    {
      client_id:,
      grant_type: 'refresh_token',
      refresh_token:,
      scope:,
      dpop_proof:,
      token_url: api_openid_connect_token_url,
    }
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_refresh_token_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
      .and_return([actor.issuer])
    allow(IdentityConfig.store).to receive(:dpop_required_issuers).and_return([actor.issuer])
  end

  def refresh_with(token, key: dpop_key)
    described_class.new(
      params.merge(
        refresh_token: token,
        dpop_proof: build_dpop_proof(http_url: api_openid_connect_token_url, key:),
      ),
    )
  end

  context 'with a valid refresh token and a proof from its key' do
    it 'returns a new key-bound subject token for the same identity and the next refresh token' do
      expect(form.submit.success?).to eq(true)
      response = form.response

      expect(response).to include(token_type: 'DPoP', scope: 'openid token_exchange')
      expect(response[:expires_in]).to eq(
        IdentityConfig.store.token_exchange_subject_token_expires_in,
      )
      subject_token = TokenExchange::SubjectToken.load(response[:access_token])
      expect(subject_token).to have_attributes(
        identity_uuid: identity.uuid,
        actor_issuer: actor.issuer,
        scope: 'openid token_exchange',
        resource:,
        actor_return_log_id: 7,
        dpop_jkt: dpop_thumbprint,
      )

      expect(response[:refresh_token]).to be_present
      expect(response[:refresh_token]).not_to eq(refresh_token)
      expect(issued.record.reload).to be_used
      expect(form.http_status).to eq(:ok)
    end

    it 'keeps the family’s scope and IAL after a later sign-in from the actor changes them' do
      identity.update!(scope: 'openid email token_exchange', ial: 2)

      subject_token = TokenExchange::SubjectToken.load(form.response[:access_token])

      expect(subject_token).to have_attributes(scope: 'openid token_exchange', ial: 1)
    end

    it 'leaves the refresh token unused when the subject token cannot be stored' do
      allow(EncryptedRedisStructStorage).to receive(:store).and_raise(Redis::CannotConnectError)

      expect { form.submit }.to raise_error(Redis::CannotConnectError)
      expect(issued.record.reload).not_to be_used
    end

    it 'can be refreshed again with the rotated token' do
      next_token = form.response[:refresh_token]

      expect(refresh_with(next_token).submit.success?).to eq(true)
    end

    it 'reports the family on the analytics attributes' do
      expect(form.submit.extra).to include(
        client_id: actor.issuer,
        user_id: user.uuid,
        token_exchange_stage: 'subject_token_refresh',
        token_exchange_resource: resource,
        refresh_token_family_id: issued.record.family_id,
        reuse_detected: false,
        oauth_error_code: nil,
      )
    end
  end

  context 'when a used refresh token is presented again with a proof from its key' do
    let!(:next_token) { form.response[:refresh_token] }

    it 'revokes the whole family, including the token that replaced it' do
      reused = refresh_with(refresh_token)

      expect(reused.submit.success?).to eq(false)
      expect(reused.response).to eq(
        error: 'invalid_grant',
        error_description: 'refresh_token_reused',
      )
      expect(reused.submit.extra[:reuse_detected]).to eq(true)
      family = TokenExchangeRefreshToken.where(family_id: issued.record.family_id)
      expect(family.pluck(:revocation_reason).uniq).to eq(['reuse_detected'])

      after_reuse = refresh_with(next_token)
      expect(after_reuse.submit.success?).to eq(false)
      expect(after_reuse.response[:error_description]).to eq('refresh_token_revoked')
    end
  end

  context 'when a used refresh token is presented with a proof from another key' do
    let!(:next_token) { form.response[:refresh_token] }

    it 'refuses the proof without revoking the family' do
      attempt = refresh_with(refresh_token, key: OpenSSL::PKey::EC.generate('prime256v1'))

      expect(attempt.response).to eq(
        error: 'invalid_dpop_proof', error_description: 'dpop_key_mismatch',
      )
      expect(refresh_with(next_token).submit.success?).to eq(true)
    end
  end

  context 'without a proof' do
    let(:dpop_proof) { nil }

    it 'fails with invalid_dpop_proof and leaves the token unused' do
      expect(form.response).to eq(
        error: 'invalid_dpop_proof',
        error_description: 'dpop_proof_missing',
      )
      expect(issued.record.reload).not_to be_used
    end
  end

  context 'with a proof that names a token' do
    let(:dpop_proof) do
      build_dpop_proof(http_url: api_openid_connect_token_url, access_token: refresh_token)
    end

    it 'fails with invalid_dpop_proof, since a refresh proof carries no ath' do
      expect(form.response).to eq(
        error: 'invalid_dpop_proof', error_description: 'dpop_proof_token_hash',
      )
    end
  end

  context 'with a proof for another URL' do
    let(:dpop_proof) { build_dpop_proof(http_url: api_openid_connect_userinfo_url) }

    it 'fails with invalid_dpop_proof' do
      expect(form.response[:error]).to eq('invalid_dpop_proof')
    end
  end

  context 'when the token has passed its idle expiry' do
    before { issued.record.update!(expires_at: 1.second.ago) }

    it 'fails with invalid_grant' do
      expect(form.response).to eq(
        error: 'invalid_grant',
        error_description: 'refresh_token_expired',
      )
    end
  end

  context 'when the family has passed its absolute lifetime' do
    before { issued.record.update!(family_expires_at: 1.second.ago) }

    it 'fails with invalid_grant' do
      expect(form.response[:error_description]).to eq('refresh_token_expired')
    end
  end

  context 'when the family was revoked' do
    before { issued.record.revoke_family!(reason: 'security_event') }

    it 'fails with invalid_grant' do
      expect(form.response).to eq(
        error: 'invalid_grant',
        error_description: 'refresh_token_revoked',
      )
    end
  end

  context 'with an unknown refresh token' do
    let(:refresh_token) { 'not-a-refresh-token' }

    it 'fails with invalid_grant' do
      expect(form.response).to eq(
        error: 'invalid_grant',
        error_description: 'refresh_token_invalid',
      )
    end
  end

  context 'when another actor presents the token' do
    let(:other_actor) { create(:service_provider, :active, pkce: true, certs: []) }
    let(:client_id) { other_actor.issuer }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
        .and_return([actor.issuer, other_actor.issuer])
      allow(IdentityConfig.store).to receive(:dpop_required_issuers)
        .and_return([actor.issuer, other_actor.issuer])
    end

    it 'fails with invalid_grant without touching the family' do
      expect(form.response[:error_description]).to eq('refresh_token_invalid')
      expect(issued.record.reload).not_to be_used
      expect(issued.record).not_to be_revoked
    end
  end

  context 'with a client that is not an allowlisted actor' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers).and_return([])
    end

    it 'fails with invalid_client and a 401' do
      expect(form.response[:error]).to eq('invalid_client')
      expect(form.http_status).to eq(:unauthorized)
    end
  end

  context 'with an actor whose tokens are not key-bound' do
    before { allow(IdentityConfig.store).to receive(:dpop_required_issuers).and_return([]) }

    it 'fails with invalid_client' do
      expect(form.response[:error]).to eq('invalid_client')
    end
  end

  context 'when refresh tokens are disabled' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_refresh_token_enabled)
        .and_return(false)
    end

    it 'fails with unsupported_grant_type and leaves the token unused' do
      expect(form.response[:error]).to eq('unsupported_grant_type')
      expect(form.http_status).to eq(:bad_request)
      expect(issued.record.reload).not_to be_used
    end
  end

  context 'without a refresh token' do
    let(:refresh_token) { nil }

    it 'fails with invalid_request' do
      expect(form.response[:error]).to eq('invalid_request')
    end
  end

  context 'with the scope the family already has' do
    let(:scope) { 'token_exchange openid' }

    it 'refreshes' do
      expect(form.submit.success?).to eq(true)
    end
  end

  context 'with a different scope' do
    let(:scope) { 'openid email token_exchange' }

    it 'fails with invalid_scope' do
      expect(form.response[:error]).to eq('invalid_scope')
    end
  end

  context 'when the person disconnected the actor' do
    before { identity.update!(deleted_at: Time.zone.now) }

    it 'fails with invalid_grant' do
      expect(form.response[:error_description]).to eq('refresh_token_identity_inactive')
    end
  end

  context 'when the account is suspended' do
    before { user.update!(suspended_at: Time.zone.now) }

    it 'fails with invalid_grant' do
      expect(form.response[:error_description]).to eq('refresh_token_identity_inactive')
    end
  end

  it 'does not depend on the Login.gov session' do
    expect(OutOfBandSessionAccessor).not_to receive(:new)

    expect(form.submit.success?).to eq(true)
  end
end
