require 'rails_helper'

describe Idv::ScanIdController do
  before do
    stub_sign_in
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
  end

  describe '#new' do
    it 'works' do
      get :new
    end
  end

  describe '#scan_complete' do
    it 'works' do
      get :scan_complete
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
    it 'works' do
      session[:scan_id] = {}
      post :liveness, body: { Image: 'foo' }.to_json
    end
  end
end
