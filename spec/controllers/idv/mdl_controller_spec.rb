require 'rails_helper'

RSpec.describe Idv::MdlController do
  include FlowPolicyHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_up_to(:how_to_verify, idv_session: controller.idv_session)
    stub_analytics
    allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(true)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::MdlController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event('IdV: mDL visited')
    end

    context 'when mdl_verification_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(false)
      end

      it 'redirects away from mdl page' do
        get :show

        expect(response).to be_redirect
        expect(response).not_to render_template(:show)
      end
    end
  end

  describe '#request_credentials' do
    it 'returns ISO 18013-7 request data' do
      post :request_credentials

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('deviceRequest')
      expect(json).to have_key('encryptionInfo')
      expect(json).to have_key('nonce')
      expect(json).to have_key('sessionId')
    end

    it 'sends analytics event with session_id' do
      post :request_credentials

      expect(@analytics).to have_logged_event(
        'IdV: mDL request generated',
        hash_including(session_id: kind_of(String)),
      )
    end

    it 'stores session data for later verification' do
      post :request_credentials

      expect(session[:mdl_verification]).to be_present
      expect(session[:mdl_verification][:session_id]).to be_present
    end
  end

  describe '#verify' do
    it 'returns success and redirect url' do
      post :verify, params: { mock: true }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(true)
      expect(json['redirect']).to eq(idv_ssn_url)
    end

    it 'populates pii_from_doc in idv_session with mock data' do
      post :verify, params: { mock: true }

      expect(controller.idv_session.pii_from_doc).to be_present
      expect(controller.idv_session.pii_from_doc.first_name).to eq('JANE')
      expect(controller.idv_session.pii_from_doc.last_name).to eq('SMITH')
    end

    it 'sends analytics_verified event' do
      post :verify, params: { mock: true }

      expect(@analytics).to have_logged_event(
        'IdV: mDL verified',
        success: true,
        used_mock_data: true,
      )
    end

    it 'clears mdl session data after successful verification' do
      # First generate a request to create session data
      post :request_credentials
      expect(session[:mdl_verification]).to be_present

      # Then verify
      post :verify, params: { mock: true }
      expect(session[:mdl_verification]).to be_nil
    end
  end
end
