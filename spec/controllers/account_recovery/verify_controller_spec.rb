require 'rails_helper'

# Phase 3 of docs/adr/0001-account-preserving-mfa-recovery.md. The routes are
# committed so the flow's shape is visible, but every action must stay inert.
RSpec.describe AccountRecovery::VerifyController do
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
    it 'renders a 404 and makes no changes' do
      stub_sign_in(user)

      expect { post :create }.to_not change { AccountRecoveryRequest.count }
      expect(response).to render_template('pages/page_not_found')
    end
  end
end
