require 'rails_helper'

RSpec.describe Idv::MdlController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:base_url) { IdentityConfig.store.okta_vdc_base_url }
  let(:auth_url) { OktaVdc::Client::DEFAULT_AUTH_URL }
  let(:session_id) { 'test-session-123' }

  before do
    allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:okta_vdc_base_url).and_return('https://credentials.okta.com')
    allow(IdentityConfig.store).to receive(:okta_vdc_client_id).and_return('test-id')
    allow(IdentityConfig.store).to receive(:okta_vdc_client_secret).and_return('test-secret')
    allow(IdentityConfig.store).to receive(:okta_vdc_oauth_domain).and_return('')
    allow(IdentityConfig.store).to receive(:okta_vdc_request_timeout).and_return(30)

    stub_request(:post, "#{auth_url}/oauth/token").to_return(
      status: 200,
      body: { access_token: 'tok', token_type: 'Bearer', expires_in: 3600 }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )

    stub_sign_in(user)
    stub_up_to(:choose_id_type, idv_session: subject.idv_session)
    subject.idv_session.idv_consent_given = true
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(described_class.step_info).to be_valid
    end
  end

  describe '#show' do
    before do
      stub_request(:post, "#{base_url}/v1/verify/initiate").to_return(
        status: 200,
        body: {
          state: { transactionId: session_id, nonce: 'n' },
          request: { request: 'jwt-token-value' },
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'renders the show template' do
      get :show
      expect(response).to render_template(:show)
    end

    it 'stores session id' do
      get :show
      expect(session[:mdl_okta_session_id]).to eq(session_id)
    end

    context 'when mdl is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(false)
      end

      it 'redirects away' do
        get :show
        expect(response).to be_redirect
      end
    end

    context 'when okta request fails' do
      before do
        stub_request(:post, "#{base_url}/v1/verify/initiate")
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'renders show with error flash' do
        get :show
        expect(response).to render_template(:show)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe '#status' do
    before do
      session[:mdl_okta_session_id] = session_id
    end

    context 'when pending' do
      before do
        stub_request(:get, "#{base_url}/v1/verify/sessions/#{session_id}/status").to_return(
          status: 200,
          body: { status: 'PENDING' }.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'returns pending' do
        get :status
        expect(JSON.parse(response.body)['status']).to eq('pending')
      end
    end

    context 'when completed' do
      before do
        stub_request(:get, "#{base_url}/v1/verify/sessions/#{session_id}/status").to_return(
          status: 200,
          body: { status: 'COMPLETED', response: 'auth-resp' }.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
        stub_request(:post, "#{base_url}/v1/verify/sessions/#{session_id}/claims").to_return(
          status: 200,
          body: {
            claims: {
              'org.iso.18013.5.1' => {
                'given_name' => 'Fakey',
                'family_name' => 'McFakerson',
                'birth_date' => '1938-10-06',
                'resident_address' => '1 Fake Rd',
                'resident_city' => 'Great Falls',
                'resident_state' => 'MT',
                'resident_postal_code' => '59010',
                'expiry_date' => '2099-12-31',
                'issue_date' => '2019-12-31',
                'issuing_authority' => 'ND',
              },
            },
          }.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'returns complete with redirect' do
        get :status
        body = JSON.parse(response.body)
        expect(body['status']).to eq('complete')
        expect(body['redirect']).to eq(idv_ssn_url)
      end

      it 'applies pii to session' do
        get :status
        expect(subject.idv_session.pii_from_doc).to be_a(Pii::StateId)
        expect(subject.idv_session.pii_from_doc.first_name).to eq('FAKEY')
      end
    end

    context 'when failed' do
      before do
        stub_request(:get, "#{base_url}/v1/verify/sessions/#{session_id}/status").to_return(
          status: 200,
          body: { status: 'FAILED' }.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'returns failed' do
        get :status
        expect(JSON.parse(response.body)['status']).to eq('failed')
      end
    end

    context 'without session id' do
      before { session.delete(:mdl_okta_session_id) }

      it 'returns error' do
        get :status
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
