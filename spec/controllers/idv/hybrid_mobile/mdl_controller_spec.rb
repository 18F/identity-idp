require 'rails_helper'

RSpec.describe Idv::HybridMobile::MdlController do
  let(:user) { create(:user) }
  let!(:document_capture_session) do
    create(
      :document_capture_session,
      user: user,
      requested_at: Time.zone.now,
      passport_status: 'not_requested',
    )
  end
  let(:tenant_url) { 'https://mdl-login.vii.us01.mattr.global' }
  let(:auth_url) { 'https://auth.us01.mattr.global' }
  let(:application_id) { 'app-id-abc' }
  let(:session_id) { 'mattr-session-xyz' }
  let(:challenge) { 'test-challenge-value' }

  before do
    session[:doc_capture_user_id] = user.id
    session[:document_capture_session_uuid] = document_capture_session.uuid

    allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:mattr_tenant_url).and_return(tenant_url)
    allow(IdentityConfig.store).to receive(:mattr_auth_url).and_return(auth_url)
    allow(IdentityConfig.store).to receive(:mattr_audience).and_return(tenant_url)
    allow(IdentityConfig.store).to receive(:mattr_application_id).and_return(application_id)
    allow(IdentityConfig.store).to receive(:mattr_client_id).and_return('cid')
    allow(IdentityConfig.store).to receive(:mattr_client_secret).and_return('csec')
    allow(IdentityConfig.store).to receive(:mattr_request_timeout).and_return(30)

    Rails.cache.delete(Mattr::VerifierClient::AUTH_TOKEN_CACHE_KEY)

    stub_request(:post, "#{auth_url}/oauth/token").to_return(
      status: 200,
      body: { access_token: 'tok', token_type: 'Bearer', expires_in: 3600 }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  describe '#show' do
    it 'renders the show template' do
      get :show
      expect(response).to render_template(:show)
    end

    it 'stores a generated challenge in the session' do
      get :show
      expect(session[Idv::HybridMobile::MdlController::CHALLENGE_SESSION_KEY]).to be_present
      expect(assigns(:challenge)).to eq(session[Idv::HybridMobile::MdlController::CHALLENGE_SESSION_KEY])
    end

    it 'exposes mattr config to the view' do
      get :show
      expect(assigns(:mattr_application_id)).to eq(application_id)
      expect(assigns(:mattr_tenant_url)).to eq(tenant_url)
      expect(assigns(:callback_path)).to eq(idv_hybrid_mobile_mdl_callback_path)
    end

    context 'when mdl verification is disabled' do
      before { allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(false) }

      it 'redirects to choose id type' do
        get :show
        expect(response).to redirect_to(idv_hybrid_mobile_choose_id_type_url)
      end
    end
  end

  describe '#callback' do
    let(:result_body) do
      {
        challenge: challenge,
        credentials: [{
          docType: 'org.iso.18013.5.1.mDL',
          verificationResult: { verified: true },
          claims: {
            'org.iso.18013.5.1' => {
              given_name: { value: 'JANE' },
              family_name: { value: 'DOE' },
              birth_date: { value: '1990-01-01' },
              resident_address: { value: '123 Fake St' },
              resident_city: { value: 'Anytown' },
              resident_state: { value: 'ZZ' },
              resident_postal_code: { value: '00000' },
              document_number: { value: 'D123456' },
              expiry_date: { value: '2030-01-01' },
              issue_date: { value: '2020-01-01' },
              issuing_authority: { value: 'ZZ' },
            },
          },
        }],
      }
    end

    before do
      session[Idv::HybridMobile::MdlController::CHALLENGE_SESSION_KEY] = challenge

      stub_request(:get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result").to_return(
        status: 200,
        body: result_body.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'returns complete with redirect to capture_complete' do
      post :callback, params: { session_id: session_id }, as: :json

      body = JSON.parse(response.body)
      expect(body['status']).to eq('complete')
      expect(body['redirect']).to eq(idv_hybrid_mobile_capture_complete_url)
    end

    it 'clears the challenge from session after success' do
      post :callback, params: { session_id: session_id }, as: :json
      expect(session[Idv::HybridMobile::MdlController::CHALLENGE_SESSION_KEY]).to be_nil
    end

    it 'stores parsed pii on the document capture session' do
      post :callback, params: { session_id: session_id }, as: :json

      stored = document_capture_session.reload.load_result
      expect(stored).to be_present
      expect(stored.success?).to be true
      expect(stored.pii_from_doc[:first_name]).to eq('JANE')
      expect(stored.pii_from_doc[:last_name]).to eq('DOE')
      expect(stored.pii_from_doc[:state_id_number]).to eq('D123456')
      expect(stored.pii_from_doc[:document_type_received]).to eq('drivers_license')
    end

    context 'when the credential fails to parse' do
      let(:result_body) do
        super().tap do |body|
          body[:credentials][0][:verificationResult] = { verified: false }
        end
      end

      it 'returns a parsing error and does not store a result' do
        post :callback, params: { session_id: session_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('credential parsing failed')
        expect(document_capture_session.reload.load_result).to be_nil
      end
    end

    context 'when session_id is missing' do
      it 'returns an error' do
        post :callback, params: {}, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['status']).to eq('error')
      end
    end

    context 'when stored challenge is missing' do
      before { session.delete(Idv::HybridMobile::MdlController::CHALLENGE_SESSION_KEY) }

      it 'returns an error' do
        post :callback, params: { session_id: session_id }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the returned challenge does not match the stored challenge' do
      let(:result_body) { super().merge(challenge: 'different-challenge') }

      it 'returns a challenge mismatch error' do
        post :callback, params: { session_id: session_id }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to match(/challenge/)
      end
    end

    context 'when no credential is returned' do
      let(:result_body) { { challenge: challenge, credentials: [] } }

      it 'returns an error' do
        post :callback, params: { session_id: session_id }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the back-channel fetch fails' do
      before do
        stub_request(:get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result")
          .to_raise(Faraday::ConnectionFailed.new('boom'))
      end

      it 'returns a verification failed error' do
        post :callback, params: { session_id: session_id }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
