require 'rails_helper'

describe Idv::ScanIdController do
  before do
    stub_sign_in
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
  end

  describe '#new' do
    it 'works' do
      stub_sign_in
      get :new
    end
  end

  describe '#scan_complete' do
    it 'works' do
      stub_sign_in
      get :scan_complete
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
end
