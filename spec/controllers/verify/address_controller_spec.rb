require 'rails_helper'

describe Verify::AddressController do
  let(:user) { build(:user) }

  before do
    stub_verify_steps_one_and_two(user)
  end

  describe '#index' do
    it 'redirects if phone mechanism selected' do
      subject.idv_session.vendor_phone_confirmation = true

      get :index

      expect(response).to redirect_to verify_review_path
    end

    it 'redirects if usps mechanism selected' do
      subject.idv_session.address_verification_mechanism = 'usps'

      get :index

      expect(response).to redirect_to verify_review_path
    end

    it 'renders index if no mechanism selected' do
      get :index

      expect(response).to be_ok
    end
  end
end
