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
      stub_attempts_tracker
      sign_in_before_2fa
    end

    describe 'GET show' do
      it 'redirects if no webauthn configured' do
        get :show
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
      context 'with webauthn configured' do
        before do
          allow_any_instance_of(TwoFactorAuthentication::WebauthnPolicy).
            to receive(:enabled?).
            and_return(true)
          allow(@analytics).to receive(:track_event)
          allow(@irs_attempts_api_tracker).to receive(:track_event)
        end
        it 'tracks an analytics event' do
          get :show, params: { platform: true }
          result = { context: 'authentication',
                     multi_factor_auth_method: 'webauthn_platform',
                     webauthn_configuration_id: nil }
          expect(@analytics).to have_received(:track_event).with(
            'Multi-Factor Authentication: enter webAuthn authentication visited',
            result,
          )
        end
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
          platform: '',
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
        result = { context: 'authentication',
                   errors: {},
                   multi_factor_auth_method: 'webauthn',
                   success: true,
                   webauthn_configuration_id: webauthn_configuration.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)
        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :mfa_login_webauthn_roaming,
          success: true,
        )

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
        result = { context: 'authentication',
                   errors: {},
                   multi_factor_auth_method: 'webauthn_platform',
                   success: true,
                   webauthn_configuration_id: WebauthnConfiguration.first.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)
        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :mfa_login_webauthn_platform,
          success: true,
        )

        patch :confirm, params: params
      end

      it 'tracks an invalid submission' do
        webauthn_configuration = create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )

        result = { context: 'authentication',
                   errors: {},
                   multi_factor_auth_method: 'webauthn',
                   success: false,
                   webauthn_configuration_id: webauthn_configuration.id }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)

        patch :confirm, params: params
      end

      context 'webauthn_platform returns an error from frontend API' do
        let(:params) do
          {
            authenticator_data: authenticator_data,
            client_data_json: verification_client_data_json,
            signature: signature,
            credential_id: credential_id,
            platform: true,
            errors: 'cannot sign in properly',
          }
        end

        before do
          controller.user_session[:webauthn_challenge] = webauthn_challenge
        end

        context 'User has multiple MFA options' do
          let(:view_context) { ActionController::Base.new.view_context }
          before do
            allow_any_instance_of(TwoFactorAuthCode::WebauthnAuthenticationPresenter).
              to receive(:multiple_factors_enabled?).
              and_return(true)
          end

          it 'redirects to webauthn show page' do
            patch :confirm, params: params
            expect(response).to redirect_to login_two_factor_webauthn_url(platform: true)
          end

          it 'displays flash error message' do
            patch :confirm, params: params
            expect(flash[:error]).to eq t(
              'two_factor_authentication.webauthn_error.multiple_methods',
              link: view_context.link_to(
                t('two_factor_authentication.webauthn_error.additional_methods_link'),
                login_two_factor_options_path,
              ),
            )
          end
        end

        context 'User only has webauthn as an MFA method' do
          before do
            allow_any_instance_of(TwoFactorAuthCode::WebauthnAuthenticationPresenter).
              to receive(:multiple_factors_enabled?).
              and_return(false)
          end

          it 'redirects to webauthn error page ' do
            patch :confirm, params: params
            expect(response).to redirect_to login_two_factor_webauthn_error_url
          end
        end
      end
    end
  end
end
