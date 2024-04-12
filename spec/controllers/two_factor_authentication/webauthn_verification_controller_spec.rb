require 'rails_helper'

RSpec.describe TwoFactorAuthentication::WebauthnVerificationController do
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
    let(:user) { create(:user) }

    before do
      stub_analytics
      stub_attempts_tracker
      sign_in_before_2fa(user)
    end

    describe 'GET show' do
      it 'redirects if no webauthn configured' do
        get :show
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end

      context 'with webauthn configured' do
        let!(:webauthn_configuration) { create(:webauthn_configuration, user:) }

        before do
          allow(@analytics).to receive(:track_event)
          allow(@irs_attempts_api_tracker).to receive(:track_event)
        end

        it 'tracks an analytics event' do
          get :show, params: { platform: true }
          result = {
            context: 'authentication',
            multi_factor_auth_method: 'webauthn_platform',
            webauthn_configuration_id: nil,
            multi_factor_auth_method_created_at: nil,
          }
          expect(@analytics).to have_received(:track_event).with(
            'Multi-Factor Authentication: enter webAuthn authentication visited',
            result,
          )
        end

        it 'assigns presenter instance variable with initialized credentials' do
          get :show

          presenter = assigns(:presenter)

          expect(presenter).to be_a(TwoFactorAuthCode::WebauthnAuthenticationPresenter)
          expect(presenter.credentials).to eq(
            [
              id: webauthn_configuration.credential_id,
              transports: webauthn_configuration.transports,
            ],
          )
        end

        context 'with multiple webauthn configured' do
          let!(:first_webauthn_platform_configuration) do
            create(:webauthn_configuration, :platform_authenticator, user:, created_at: 2.days.ago)
          end
          let!(:second_webauthn_platform_configuration) do
            create(:webauthn_configuration, :platform_authenticator, user:, created_at: 1.day.ago)
          end

          it 'filters credentials based on requested attachment, sorted descending by date' do
            get :show

            expect(assigns(:presenter).credentials).to eq(
              [
                id: webauthn_configuration.credential_id,
                transports: webauthn_configuration.transports,
              ],
            )

            get :show, params: { platform: true }

            expect(assigns(:presenter).credentials).to eq(
              [
                {
                  id: second_webauthn_platform_configuration.credential_id,
                  transports: second_webauthn_platform_configuration.transports,
                },
                {
                  id: first_webauthn_platform_configuration.credential_id,
                  transports: first_webauthn_platform_configuration.transports,
                },
              ],
            )
          end
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

      context 'with a valid submission' do
        let!(:webauthn_configuration) do
          create(
            :webauthn_configuration,
            user: controller.current_user,
            credential_id: credential_id,
            credential_public_key: credential_public_key,
          )
          controller.current_user.webauthn_configurations.first
        end
        let(:result) do
          {
            context: 'authentication',
            multi_factor_auth_method: 'webauthn',
            success: true,
            webauthn_configuration_id: webauthn_configuration.id,
            multi_factor_auth_method_created_at: webauthn_configuration.created_at.strftime('%s%L'),
            new_device: nil,
          }
        end

        before do
          allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        end

        it 'tracks a valid submission' do
          expect(@analytics).to receive(:track_mfa_submit_event).
            with(result)
          expect(@analytics).to receive(:track_event).
            with('User marked authenticated', authentication_type: :valid_2fa)

          expect(@irs_attempts_api_tracker).to receive(:track_event).with(
            :mfa_login_webauthn_roaming,
            success: true,
          )
          expect(controller).to receive(:handle_valid_verification_for_authentication_context).
            with(auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN).
            and_call_original

          freeze_time do
            patch :confirm, params: params

            expect(subject.user_session[:auth_events]).to eq(
              [
                auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
                at: Time.zone.now,
              ],
            )
            expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
          end
        end

        context 'with platform authenticator' do
          let!(:webauthn_configuration) do
            create(
              :webauthn_configuration,
              :platform_authenticator,
              user: controller.current_user,
              credential_id: credential_id,
              credential_public_key: credential_public_key,
            )
            controller.current_user.webauthn_configurations.first
          end
          let(:result) { super().merge(multi_factor_auth_method: 'webauthn_platform') }

          it 'tracks a valid submission' do
            expect(@analytics).to receive(:track_mfa_submit_event).
              with(result)
            expect(@analytics).to receive(:track_event).
              with('User marked authenticated', authentication_type: :valid_2fa)

            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :mfa_login_webauthn_platform,
              success: true,
            )

            freeze_time do
              patch :confirm, params: params
              expect(subject.user_session[:auth_events]).to eq(
                [
                  auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
                  at: Time.zone.now,
                ],
              )
              expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(
                false,
              )
            end
          end
        end
      end

      context 'with new device session value' do
        let!(:webauthn_configuration) do
          create(
            :webauthn_configuration,
            user: controller.current_user,
            credential_id: credential_id,
            credential_public_key: credential_public_key,
          )
          controller.current_user.webauthn_configurations.first
        end
        let(:result) do
          {
            context: 'authentication',
            multi_factor_auth_method: 'webauthn',
            success: true,
            webauthn_configuration_id: webauthn_configuration.id,
            multi_factor_auth_method_created_at: webauthn_configuration.created_at.strftime('%s%L'),
            new_device: false,
          }
        end

        before do
          allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
          subject.user_session[:new_device] = false
        end

        it 'tracks new device value' do
          expect(@analytics).to receive(:track_mfa_submit_event).
            with(result)

          freeze_time do
            patch :confirm, params: params
          end
        end
      end

      it 'tracks an invalid submission' do
        create(
          :webauthn_configuration,
          user: controller.current_user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
        webauthn_configuration = controller.current_user.webauthn_configurations.first
        result = { context: 'authentication',
                   multi_factor_auth_method: 'webauthn',
                   success: false,
                   error_details: { authenticator_data: { invalid_authenticator_data: true } },
                   webauthn_configuration_id: webauthn_configuration.id,
                   multi_factor_auth_method_created_at: webauthn_configuration.created_at.
                     strftime('%s%L'),
                   new_device: nil }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(result)
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        patch :confirm, params: params
      end

      context 'webauthn_platform returns an error from frontend API' do
        let(:webauthn_error) { 'NotAllowedError' }
        let(:params) do
          {
            authenticator_data: '',
            client_data_json: '',
            signature: '',
            credential_id: '',
            platform: true,
            webauthn_error: webauthn_error,
          }
        end

        before do
          controller.user_session[:webauthn_challenge] = webauthn_challenge
        end

        let(:view_context) { ActionController::Base.new.view_context }
        let!(:first_webauthn_platform_configuration) do
          create(:webauthn_configuration, :platform_authenticator, user:, created_at: 2.days.ago)
        end
        let!(:second_webauthn_platform_configuration) do
          create(:webauthn_configuration, :platform_authenticator, user:, created_at: 1.day.ago)
        end

        it 'redirects to webauthn show page' do
          patch :confirm, params: params
          expect(response).to redirect_to login_two_factor_webauthn_url(platform: true)
          expect(subject.user_session[:auth_events]).to eq nil
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
        end

        it 'displays flash error message' do
          patch :confirm, params: params
          expect(flash[:error]).to eq t(
            'two_factor_authentication.webauthn_error.try_again',
            link: view_context.link_to(
              t('two_factor_authentication.webauthn_error.additional_methods_link'),
              login_two_factor_options_path,
            ),
          )
        end

        it 'logs an event with error details' do
          expect(@analytics).to receive(:track_mfa_submit_event).with(
            success: false,
            error_details: {
              authenticator_data: { blank: true },
              client_data_json: { blank: true },
              signature: { blank: true },
              webauthn_configuration: { blank: true },
              webauthn_error: { present: true },
            },
            context: UserSessionContext::AUTHENTICATION_CONTEXT,
            multi_factor_auth_method: 'webauthn_platform',
            multi_factor_auth_method_created_at:
              second_webauthn_platform_configuration.created_at.strftime('%s%L'),
            new_device: nil,
            webauthn_configuration_id: nil,
            frontend_error: webauthn_error,
          )

          patch :confirm, params: params
        end
      end
    end
  end
end
