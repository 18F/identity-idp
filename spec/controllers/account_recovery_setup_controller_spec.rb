require 'rails_helper'

#todo clara convert this into a spec for 2+ factors vs not
describe AccountRecoverySetupController do
=begin
  context 'user is not piv_cac enabled' do
    it 'redirects to account_url' do
      stub_sign_in

      get :index

      expect(response).to redirect_to account_url
    end
  end

  context 'user is piv_cac enabled and phone enabled' do
    it 'redirects to account_url' do
      user = build(:user, :signed_up, :with_piv_or_cac, :with_email)
      stub_sign_in(user)

      get :index

      expect(response).to redirect_to account_url
    end
  end

  context 'user is piv_cac enabled but not phone enabled' do
    it 'redirects to account_url' do
      user = build(:user, :signed_up, :with_piv_or_cac, :with_email, with: { mfa_enabled: false })
      stub_sign_in(user)

      get :index

      expect(response).to render_template(:index)
    end
  end
=end
end
