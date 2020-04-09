require 'rails_helper'

describe Idv::ScanIdAcuantController do
  let(:instance_id) { '3899aab2-1da7-4e64-8c31-238f279663fc' }

  before do |test|
    stub_sign_in unless test.metadata[:skip_sign_in]
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
  end

  describe '#field_image' do
    it 'fetches an image from the uploaded document instance id' do
      get :field_image, params: { instance_id: 'foo' }
      expect(response.body).to eq('{}')
    end
  end

  describe '#subscriptions' do
    it 'fetches the subscription settings related to the account' do
      get :subscriptions
      expect(response.body).to eq(Acuant::Subscriptions::SUBSCRIPTION_DATA.to_json)
    end
  end

  describe '#instance' do
    it 'creates a new working document and returns an instance id' do
      post :instance
      expect(response.body).to eq(instance_id)
    end
  end

  describe '#document' do
    it 'fetches the results of analysis of the uploaded front and back of a document' do
      session[:scan_id] = {}
      get :document, params: { instance_id: 'foo' }
      expect(response.body).to eq(Idv::Acuant::FakeAssureId::FAKE_DATA.to_json)
    end
  end

  describe '#image' do
    it 'allows the user to upload an image for the working document' do
      post :image, params: { instance_id: 'foo' }
      expect(response.body).to eq([true, ''].to_json)
    end
  end

  describe '#classification' do
    it 'fetches the classification of the document so we can handle multiple document types' do
      get :classification, params: { instance_id: 'foo' }
      expect(response.body).to eq(Acuant::Classification::CLASSIFICATION_DATA.to_json)
    end
  end

  describe '#facematch' do
    it 'determines whether two images match (ie selfie and license image)' do
      post :facematch
      expect(response.body).to eq('{}')
    end
  end

  describe '#liveness' do
    it 'identifies live selfies as live' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(response.body).to eq('{}')
      expect(session[:scan_id][:liveness_pass]).to eq(true)
    end

    it 'rejects images that are not live selfies' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'not-live-selfie' }.to_json
      expect(response.body).to eq('{}')
      expect(session[:scan_id][:liveness_pass]).to be_falsey
    end

    it 'does not do selfie checking if liveness checking is disabled' do
      allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('false')
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(response.body).to eq('{}')
      expect(session[:scan_id][:liveness_pass]).to be_falsey
    end

    it 'throttles liveness' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'live-selfie' }.to_json
      expect(response.body).to eq('{}')
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
