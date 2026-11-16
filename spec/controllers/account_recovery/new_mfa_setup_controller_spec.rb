require 'rails_helper'

# Reached only with the temporary pre-2FA session created by password
# verification and suspension of the previous MFA methods.
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

      it 'renders the page for a request awaiting replacement MFA' do
        create(:account_recovery_request, :replacement_mfa_pending, user: user)

        get :show

        expect(response).to render_template(:show)
      end

      it 'logs the visit with the recovery state' do
        stub_analytics
        create(:account_recovery_request, :replacement_mfa_pending, user: user)

        get :show

        expect(@analytics).to have_logged_event(
          :account_recovery_new_mfa_setup_visit,
          recovery_state: AccountRecoveryRequest::REPLACEMENT_MFA_PENDING,
        )
      end

      it 'is not found for a newly requested request' do
        create(:account_recovery_request, user: user)

        get :show

        expect(response).to render_template('pages/page_not_found')
      end

      %i[
        waiting granted link_verified password_verified cancelled expired completed
      ].each do |state|
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
        create(:account_recovery_request, :replacement_mfa_pending)

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

  context 'after password verification and suspension' do
    before do
      stub_sign_in_before_2fa(user)
      recovery_request = create(:account_recovery_request, :password_verified, user: user)
      AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
    end

    it 'renders normal enrollment choices without authenticating the user' do
      get :show

      expect(response).to render_template(:show)
      expect(controller.send(:user_fully_authenticated?)).to eq(false)
    end

    {
      'phone' => :phone_setup_url,
      'auth_app' => :authenticator_setup_url,
      'webauthn' => :webauthn_setup_url,
      'piv_cac' => :setup_piv_cac_url,
      'backup_code' => :backup_code_setup_url,
    }.each do |selection, route|
      it "routes #{selection} to its normal enrollment path" do
        post :create, params: { two_factor_options_form: { selection: [selection] } }

        expect(response).to redirect_to(public_send(route))
        expect(controller.send(:user_fully_authenticated?)).to eq(false)
      end
    end

    it 'routes passkeys to platform enrollment' do
      post :create, params: { two_factor_options_form: { selection: ['webauthn_platform'] } }

      expect(response).to redirect_to(webauthn_setup_url(platform: true))
    end

    it 'stores multiple selections and routes to the first one' do
      post :create, params: { two_factor_options_form: { selection: %w[auth_app backup_code] } }

      expect(response).to redirect_to(authenticator_setup_url)
      expect(controller.user_session[:mfa_selections]).to eq(%w[auth_app backup_code])
      expect(controller.send(:user_fully_authenticated?)).to eq(false)
    end

    it 'rejects an empty selection' do
      post :create, params: { two_factor_options_form: { selection: [] } }

      expect(response).to render_template(:show)
      expect(controller.user_session[:mfa_selections]).to be_nil
      expect(controller.send(:user_fully_authenticated?)).to eq(false)
    end

    it 'rejects unsupported methods' do
      post :create, params: { two_factor_options_form: { selection: ['personal_key'] } }

      expect(response).to render_template(:show)
    end
  end
end
