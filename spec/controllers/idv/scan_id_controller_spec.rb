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
  end

  describe '#field_image' do
    it 'works' do
      get :field_image, params: { instance_id: 'foo' }
    end
  end

  describe '#subscriptions' do
    it 'works' do
      get :subscriptions
    end
  end

  describe '#instance' do
    it 'works' do
      post :instance
    end
  end

  describe '#document' do
    it 'works' do
      session[:scan_id] = {}
      get :document, params: { instance_id: 'foo' }
    end
  end

  describe '#image' do
    it 'works' do
      post :image, params: { instance_id: 'foo' }
    end
  end

  describe '#classification' do
    it 'works' do
      get :classification, params: { instance_id: 'foo' }
    end
  end

  describe '#facematch' do
    it 'works' do
      post :facematch
    end
  end

  describe '#liveness' do
    it 'identifies live selfies as live' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(session[:scan_id][:liveness_pass]).to eq(true)
    end

    it 'rejects images that are not live selfies' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'not-live-selfie' }.to_json
      expect(session[:scan_id][:liveness_pass]).to be_falsey
    end

    it 'does not do selfie checking if liveness checking is disabled' do
      allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('false')
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(session[:scan_id][:liveness_pass]).to be_falsey
    end

    it 'throttles liveness' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(session[:scan_id][:liveness_pass]).to eq(true)

      20.times do
        post :liveness, body: { Image: 'live-selfie' }.to_json
      end

      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(session[:scan_id][:liveness_pass]).to be_falsey
    end
  end
end
