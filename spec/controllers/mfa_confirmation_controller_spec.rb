require 'rails_helper'

RSpec.describe MfaConfirmationController do
  describe '#show' do
    it 'presents the mfa confirmation page.' do
      stub_sign_in

      get :show, params: { final_path: account_url }

      expect(response.status).to eq 200
    end
  end
end
