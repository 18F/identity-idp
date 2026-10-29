require 'rails_helper'

# Replacement MFA setup requires the recovery authorization and suspension
# ledger from later phases. Until then this controller
# must never grant access to MFA setup.
RSpec.describe AccountRecovery::NewMfaSetupController do
  let(:user) { create(:user, :fully_registered) }

  describe '#show' do
    it 'renders a 404 for an anonymous visitor' do
      get :show

      expect(response).to render_template('pages/page_not_found')
    end

    it 'renders a 404 for a signed-in user' do
      stub_sign_in(user)

      get :show

      expect(response).to render_template('pages/page_not_found')
    end
  end

  describe '#create' do
    it 'renders a 404 and does not alter MFA configurations' do
      stub_sign_in(user)

      expect { post :create }.to_not change { user.reload.phone_configurations.count }
      expect(response).to render_template('pages/page_not_found')
    end
  end
end
