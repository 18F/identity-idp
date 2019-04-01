require 'rails_helper'

describe TwoFactorAuthentication::WebauthnVerificationController do
  include WebauthnVerificationHelper

  describe 'when not signed in' do
    describe 'GET show' do
      it 'redirects to root url' do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end

    describe 'patch confirm' do
      it 'redirects to root url' do
        patch :confirm

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when signed in before 2fa' do
    before do
      stub_analytics
      sign_in_before_2fa
    end

    describe 'GET show' do
      it 'saves challenge in session and renders show' do
        create_webauthn_configuration(controller.current_user)
        get :show

        expect(subject.user_session[:webauthn_challenge].length).to eq(32)
        expect(response).to render_template(:show)
      end

      it 'redirects if no webauthn configured' do
        get :show

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          authenticator_data: authenticator_data,
          client_data_json: client_data_json,
          signature: signature,
          credential_id: credential_id,
          ga_client_id: 'abc-cool-town-5',
        }
      end
      before do
        controller.user_session[:webauthn_challenge] = challenge
        create_webauthn_configuration(controller.current_user)
      end

      it 'processes an invalid webauthn' do
        # the wrong domain name is embedded in the assertion test data
        patch :confirm, params: params

        expect(response).to redirect_to(login_two_factor_webauthn_url)
      end

      it 'processes a valid webauthn' do
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        patch :confirm, params: params

        expect(response).to redirect_to(account_url)
      end

      it 'tracks the submission' do
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        result = { context: 'authentication', errors: {}, multi_factor_auth_method: 'webauthn',
                   success: true }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result, 'abc-cool-town-5')

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_MARKED_AUTHED, authentication_type: :valid_2fa)

        patch :confirm, params: params
      end
    end
  end
end
