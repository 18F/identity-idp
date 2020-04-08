require 'rails_helper'

describe AssureIdServiceController do
  before do
    allow(Figaro.env).to receive(:enable_mobile_capture).and_return('true')
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
      get :document, params: { guid: 'foo' }
    end
  end

  describe '#image' do
    it 'works' do
      post :image, params: { guid: 'foo' }
    end
  end

  describe '#classification' do
    it 'works' do
      get :classification, params: { guid: 'foo' }
    end
  end

  describe '#liveness' do
    it 'works' do
      post :liveness
    end
  end

  describe '#facematch' do
    it 'works' do
      post :facematch
    end
  end
end
