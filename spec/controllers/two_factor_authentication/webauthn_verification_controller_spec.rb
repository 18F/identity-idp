require 'rails_helper'

describe TwoFactorAuthentication::WebauthnVerificationController do
  include WebAuthnHelper

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
      it 'redirects if no webauthn configured' do
        get :show

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
        }
      end
      before do
        controller.user_session[:webauthn_challenge] = webauthn_challenge
      end

      it 'tracks a valid non-platform authenticator submission' do
        webauthn_configuration = create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        result = { context: 'authentication', errors: {}, multi_factor_auth_method: 'webauthn',
                   success: true, webauthn_configuration_id: webauthn_configuration.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)
        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_MARKED_AUTHED, authentication_type: :valid_2fa)

        patch :confirm, params: params
      end

      it 'tracks a valid platform authenticator submission' do
        create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
          platform_authenticator: true,
        )
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        result = { context: 'authentication', errors: {},
                   multi_factor_auth_method: 'webauthn_platform',
                   success: true, webauthn_configuration_id: WebauthnConfiguration.first.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)
        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_MARKED_AUTHED, authentication_type: :valid_2fa)

        patch :confirm, params: params
      end

      it 'tracks an invalid submission' do
        webauthn_configuration = create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )

        result = { context: 'authentication', errors: {}, multi_factor_auth_method: 'webauthn',
                   success: false, webauthn_configuration_id: webauthn_configuration.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)

        patch :confirm, params: params
      end
    end
  end
end
