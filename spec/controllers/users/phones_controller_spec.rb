require 'rails_helper'

describe Users::PhonesController do
  let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
  before do
    stub_sign_in(user)

    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  context 'user adds phone' do
    it 'gives the user a form to enter a new phone number' do
      get :add

      expect(response).to render_template(:add)
      expect(response.request.flash[:alert]).to be_nil
    end
  end

  context 'user exceeds phone number limit' do
    before do
      user.phone_configurations.create(encrypted_phone: '4105555551')
      user.phone_configurations.create(encrypted_phone: '4105555552')
      user.phone_configurations.create(encrypted_phone: '4105555553')
      user.phone_configurations.create(encrypted_phone: '4105555554')
    end

    it 'displays error if phone number exceeds limit' do
      controller.request.headers.merge({ HTTP_REFERER: account_url })

      get :add
      expect(response).to redirect_to(account_url(anchor: 'phones'))
      expect(response.request.flash[:phone_error]).to_not be_nil
    end

    it 'renders the #phone anchor when it exceeds limit' do
      controller.request.headers.merge({ HTTP_REFERER: account_url })

      get :add
      expect(response.location).to include('#phone')
    end

    it 'it redirects to two factor auth url if the referer was two factor auth' do
      controller.request.headers.merge({ HTTP_REFERER: account_two_factor_authentication_url })

      get :add
      expect(response).to redirect_to(account_two_factor_authentication_url(anchor: 'phones'))
    end

    it 'defaults to account url if the url is anything but two factor auth url' do
      controller.request.headers.merge({ HTTP_REFERER: add_phone_url })

      get :add
      expect(response).to redirect_to(account_url(anchor: 'phones'))
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
