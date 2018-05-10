require 'rails_helper'

describe Idv::AddressController do
  let(:user) { build(:user) }

  before do
    stub_verify_steps_one_and_two(user)
  end

  describe '#index' do
    it 'redirects if phone mechanism selected' do
      subject.idv_session.vendor_phone_confirmation = true

      get :index

      expect(response).to redirect_to idv_review_path
    end

    it 'redirects if usps mechanism selected' do
      subject.idv_session.address_verification_mechanism = 'usps'

      get :index

      expect(response).to redirect_to idv_review_path
    end

    it 'renders index if no mechanism selected' do
      get :index

      expect(response).to be_ok
    end
  end

  describe '#create' do
    it 'tracks the address delivery method event when phone is selected' do
      stub_analytics
      analytics_hash = { address_delivery_method: 'phone', success: true, errors: {} }

      expect(@analytics).to receive(:track_event).
        with(Analytics::IDV_ADDRESS_VERIFICATION_SELECTION, analytics_hash)

      post :create, params: { address_delivery_method: 'phone' }
    end

    it 'tracks the address delivery method event when usps is selected' do
      stub_analytics
      analytics_hash = { address_delivery_method: 'usps', success: true, errors: {} }

      expect(@analytics).to receive(:track_event).
        with(Analytics::IDV_ADDRESS_VERIFICATION_SELECTION, analytics_hash)

      post :create, params: { address_delivery_method: 'usps' }
    end
  end
end
