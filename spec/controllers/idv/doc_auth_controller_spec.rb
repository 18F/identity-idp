require 'rails_helper'

RSpec.describe Idv::DocAuthController do
  include DocAuthHelper

  let(:user) { build(:user) }

  before do
    stub_sign_in(user) if user
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#index' do
    it 'redirects to welcome_url' do
      get :index

      expect(response).to redirect_to idv_welcome_url
    end

    it 'logs that it was visited' do
      get :index

      expect(@analytics).to have_received(:track_event).with(
        'DocAuthController index',
        step: nil,
        referer: nil,
      )
    end
  end

  describe '#show' do
    it 'redirects to welcome_url' do
      get :show, params: { step: 'foo' }

      expect(response).to redirect_to idv_welcome_url
    end

    it 'logs that it was visited' do
      get :show, params: { step: 'foo' }

      expect(@analytics).to have_received(:track_event).with(
        'DocAuthController show',
        step: 'foo',
        referer: nil,
      )
    end
  end

  describe '#update' do
    it 'redirects to welcome_url' do
      put :update, params: { step: 'foo' }

      expect(response).to redirect_to idv_welcome_url
    end

    it 'logs that it was visited' do
      referer = '/surprise/referer'
      request.env['HTTP_REFERER'] = referer
      put :update, params: { step: 'foo' }

      expect(@analytics).to have_received(:track_event).with(
        'DocAuthController update',
        step: 'foo',
        referer: referer,
      )
    end
  end
end
