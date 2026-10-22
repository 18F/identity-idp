require 'rails_helper'

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
      expect(controller.user_session[:context]).to eq('confirmation')
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

    it 'rejects a selection that includes a method not offered on the page' do
      allow_any_instance_of(TwoFactorOptionsPresenter).to receive(:options).and_return(
        [TwoFactorAuthentication::SetUpAuthAppSelectionPresenter.new(user: user)],
      )

      post :create, params: { two_factor_options_form: { selection: %w[auth_app backup_code] } }

      expect(response).to render_template(:show)
      expect(controller.user_session[:mfa_selections]).to be_nil
    end
  end
end
