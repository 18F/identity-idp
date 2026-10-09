require 'rails_helper'

# The authorization-code grant at POST /api/openid_connect/token for a public client approved
# for delegated access, whose code and access token are bound to its DPoP key (RFC 9449).
RSpec.describe 'OpenID Connect token endpoint, DPoP-bound authorization code' do
  include Rails.application.routes.url_helpers

  let(:service_provider) do
    create(:service_provider, :delegation_service_provider, pkce: true, certs: [])
  end
  let(:user) { create(:user, :proofed) }
  let(:code_verifier) { SecureRandom.urlsafe_base64(32) }
  let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }
  let!(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      nonce: SecureRandom.hex,
      rails_session_id: SecureRandom.hex,
      ial: 2,
      code_challenge:,
      dpop_jkt: dpop_thumbprint,
      scope: 'openid email',
    )
  end
  let(:params) do
    { grant_type: 'authorization_code', code: identity.session_uuid, code_verifier: }
  end
  let(:json) { JSON.parse(response.body, symbolize_names: true) }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(300)
  end

  it 'issues a DPoP access token when the header carries a proof from the bound key' do
    post api_openid_connect_token_path,
         params:, headers: { 'DPoP' => build_dpop_proof(url: api_openid_connect_token_url) }

    expect(response).to have_http_status(:ok)
    expect(json[:token_type]).to eq('DPoP')
    expect(json[:access_token]).to eq(identity.access_token)
    expect(json[:id_token]).to be_present
  end

  it 'refuses the redemption without a proof' do
    post api_openid_connect_token_path, params: params

    expect(response).to have_http_status(:bad_request)
    expect(json[:error]).to eq('invalid_dpop_proof')
    expect(json[:error_description]).to eq(t('openid_connect.token.errors.dpop_proof_required'))
  end

  it 'refuses a proof from another key' do
    other = OpenSSL::PKey::EC.generate('prime256v1')
    proof = build_dpop_proof(url: api_openid_connect_token_url, key: other)
    post api_openid_connect_token_path, params:, headers: { 'DPoP' => proof }

    expect(response).to have_http_status(:bad_request)
    expect(json[:error]).to eq('invalid_dpop_proof')
    expect(json[:error_description]).to eq(t('openid_connect.token.errors.dpop_key_mismatch'))
  end

  it 'ignores a proof sent in the body' do
    post api_openid_connect_token_path,
         params: params.merge(dpop_proof: build_dpop_proof(url: api_openid_connect_token_url))

    expect(response).to have_http_status(:bad_request)
    expect(json[:error]).to eq('invalid_dpop_proof')
  end
end
