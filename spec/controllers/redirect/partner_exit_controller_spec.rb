require 'rails_helper'

RSpec.describe Redirect::PartnerExitController do
  describe '#show' do
    let(:user) { create(:user, :fully_registered) }

    before do
      stub_sign_in_before_2fa(user)
      stub_analytics
    end

    it 'redirects with no service provider attached' do
      get 'show'

      expect(response).to redirect_to(account_path)
    end
  end
end
