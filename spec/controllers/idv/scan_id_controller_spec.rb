require 'rails_helper'

describe Idv::ScanIdController do
  before do |test|
    stub_sign_in unless test.metadata[:skip_sign_in]
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
  end

  describe '#new' do
    it 'renders the scan id page' do
      get :new
      expect(response).to render_template(:new)
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

      it 'renders the scan id page with a good token' do
        token = CaptureDoc::CreateRequest.call(create(:user).id).request_token
        get :new, params: { token: token }

        expect(response).to render_template(:new)
      end
    end
  end

  describe '#scan_complete' do
    it 'renders an error page when all the checks do not pass' do
      get :scan_complete
      expect(response).to redirect_to idv_session_errors_warning_url
    end

    it 'redirects to ssn page whe all the checks pass' do
      controller.user_session['idv/doc_auth_v2'] = {}
      session[:scan_id] = { instance_id: 'foo', liveness_pass: true, facematch_pass: true, pii: {} }
      get :scan_complete
      expect(response).to redirect_to(idv_doc_auth_v2_step_url(step: :ssn))
    end

    it 'redirects to ssn page when liveness fails but liveness is disabled for all sps' do
      allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('false')
      controller.user_session['idv/doc_auth_v2'] = {}
      session[:scan_id] = { instance_id: 'foo', liveness_pass: false, facematch_pass: false, pii: {} }
      get :scan_complete
      expect(response).to redirect_to(idv_doc_auth_v2_step_url(step: :ssn))
    end

    it 'renders scan id complete page when all the checks pass in hybrid flow', :skip_sign_in do
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
