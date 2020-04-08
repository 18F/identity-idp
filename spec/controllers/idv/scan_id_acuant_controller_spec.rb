require 'rails_helper'

describe Idv::ScanIdAcuantController do
  before do |test|
    stub_sign_in unless test.metadata[:skip_sign_in]
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
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
