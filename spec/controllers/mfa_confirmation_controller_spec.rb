require 'rails_helper'

RSpec.describe MfaConfirmationController do
  describe '#show' do
    it 'presents the mfa confirmation page.' do
      stub_sign_in

      get :show, params: { final_path: account_url }

      expect(response.status).to eq 200
    end
  end

  describe '#skip' do
    let(:user) { create(:user, :with_webauthn_platform) }

    before do
      stub_analytics
      stub_sign_in(user)
    end

    it 'tracks the setup as complete' do
      post :skip

      expect(@analytics).to have_logged_event(
        'User Registration: MFA Setup Complete',
        success: true,
        mfa_method_counts: { webauthn_platform: 1 },
        enabled_mfa_methods_count: 1,
        auto_passkey_prompted: false,
      )
    end

    context 'when the user is automatically prompted to set up a passkey' do
      before do
        allow(controller).to receive(:mobile?).and_return(true)
        controller.user_session[:auto_passkey_prompted] = true
        controller.user_session[:in_account_creation_flow] = true
      end

      it 'logs auto passkey prompt as true' do
        post :skip

        expect(@analytics).to have_logged_event(
          'User Registration: MFA Setup Complete',
          hash_including(auto_passkey_prompted: true),
        )
      end
    end
  end
end
