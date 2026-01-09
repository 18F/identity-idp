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
    it 'returns a signed request and nonce' do
      post :request_credentials

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('signedRequest')
      expect(json).to have_key('nonce')
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

    it 'populates pii_from_doc in idv_session' do
      post :verify, params: { mock: true }

      expect(controller.idv_session.pii_from_doc).to be_present
      expect(controller.idv_session.pii_from_doc.first_name).to eq('APPLE')
      expect(controller.idv_session.pii_from_doc.last_name).to eq('WALLET')
    end

    it 'sends analytics_verified event' do
      post :verify, params: { mock: true }

      expect(@analytics).to have_logged_event('IdV: mDL verified', success: true)
    end
  end
end
