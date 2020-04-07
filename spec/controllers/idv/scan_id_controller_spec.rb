require 'rails_helper'

describe Idv::ScanIdController do
  before do |test|
    stub_sign_in unless test.metadata[:skip_sign_in]
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
  end

  describe '#new' do
    it 'works' do
      get :new
    end

    context 'no user signed in', :skip_sign_in do
      it 'redirects to the root url with no token' do
        get :new

        expect(response).to redirect_to root_url
      end

      it 'redirects to the root url with a bad token' do
        get :new, params: { token: 'foo' }

        expect(response).to redirect_to root_url
      end

      it 'redirects to the root url with a bad token' do
        get :new, params: { token: 'foo' }

        expect(response).to redirect_to root_url
      end

      it 'works with a good token' do
        token = CaptureDoc::CreateRequest.call(create(:user).id).request_token
        get :new, params: { token: token }

        expect(response).to render_template(:new)
      end
    end
  end

  describe '#scan_complete' do
    it 'works' do
      get :scan_complete
    end

    it 'works when all the checks pass' do
      controller.user_session['idv/doc_auth_v2'] = {}
      session[:scan_id] = { instance_id: 'foo', liveness_pass: true, facematch_pass: true, pii: {} }
      get :scan_complete
      expect(response).to redirect_to(idv_doc_auth_v2_step_url(step: :ssn))
    end

    it 'works when all the checks pass in hybrid flow', :skip_sign_in do
      token = CaptureDoc::CreateRequest.call(create(:user).id).request_token
      get :new, params: { token: token }

      session[:scan_id] = { instance_id: 'foo', liveness_pass: true, facematch_pass: true, pii: {} }
      get :scan_complete
      expect(response).to render_template(:capture_complete)
    end

    it 'displays throttled page when throttled' do
      allow(Throttler::IsThrottled).to receive(:call).and_return(true)
      get :scan_complete
      expect(response).to redirect_to idv_session_errors_throttled_url
    end
  end
end
