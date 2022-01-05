require 'rails_helper'

describe Users::PhonesController do
  include Features::MailerHelper

  let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
  before do
    stub_sign_in(user)

    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  context 'user adds phone' d
    it 'gives the user a form to enter a new phone number' do
      get :add

      expect(response).to render_template(:add)
      expect(response.request.flash[:alert]).to be_nil

    end

    it 'displays error if phone number exceeds limit' do
      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')

      get :add
      expect(response).to redirect_to(account_url + '#phones')
      expect(response.request.flash[:phone_error]).to_not be_nil
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).and_return(true)
    end

    it 'redirects to outage page' do
      get :add

      expect(response).to redirect_to vendor_outage_path(from: :users_phones)
    end
  end
end
