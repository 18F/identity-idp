require 'rails_helper'

# Reached only with the temporary pre-2FA session created by password
# verification. Replacement MFA selection is added in a later phase.
RSpec.describe AccountRecovery::NewMfaSetupController do
  let(:user) { create(:user, :fully_registered) }

  describe '#show' do
    it 'is not found for an anonymous visitor' do
      create(:account_recovery_request, :password_verified, user: user)

      get :show

      expect(response).to render_template('pages/page_not_found')
    end

    context 'with a temporary recovery session' do
      before { stub_sign_in_before_2fa(user) }

      it 'renders the page for a password-verified request' do
        create(:account_recovery_request, :password_verified, user: user)

        get :show

        expect(response).to render_template(:show)
      end

      it 'logs the visit with the recovery state' do
        stub_analytics
        create(:account_recovery_request, :password_verified, user: user)

        get :show

        expect(@analytics).to have_logged_event(
          :account_recovery_new_mfa_setup_visit,
          recovery_state: AccountRecoveryRequest::PASSWORD_VERIFIED,
        )
      end

      it 'is not found for a newly requested request' do
        create(:account_recovery_request, user: user)

        get :show

        expect(response).to render_template('pages/page_not_found')
      end

      %i[waiting granted link_verified cancelled expired completed].each do |state|
        it "is not found for a #{state} request" do
          create(:account_recovery_request, state, user: user)

          get :show

          expect(response).to render_template('pages/page_not_found')
        end
      end

      it 'is not found without a request' do
        get :show

        expect(response).to render_template('pages/page_not_found')
      end

      it 'does not use another user’s request' do
        create(:account_recovery_request, :password_verified)

        get :show

        expect(response).to render_template('pages/page_not_found')
      end
    end

    context 'with a fully authenticated session' do
      it 'is not found' do
        stub_sign_in(user)
        create(:account_recovery_request, :password_verified, user: user)

        get :show

        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#create' do
    it 'is not available yet' do
      stub_sign_in_before_2fa(user)
      create(:account_recovery_request, :password_verified, user: user)

      post :create

      expect(response).to render_template('pages/page_not_found')
    end
  end
end
