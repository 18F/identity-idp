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

        it 'tracks an analytics event' do
          get :show, params: { platform: true }

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication: enter webAuthn authentication visited',
            context: 'authentication',
            multi_factor_auth_method: 'webauthn_platform',
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

        context 'when there is a sign_in_recaptcha_assessment_id in the session' do
          let(:assessment_id) { 'projects/project-id/assessments/assessment-id' }

          it 'annotates the assessment with INITIATED_TWO_FACTOR and logs the annotation' do
            recaptcha_annotation = {
              assessment_id:,
              reason: RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
            }

            controller.session[:sign_in_recaptcha_assessment_id] = assessment_id

            expect(RecaptchaAnnotator).to receive(:annotate)
              .with(**recaptcha_annotation)
              .and_return(recaptcha_annotation)

            get :show

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication: enter webAuthn authentication visited',
              hash_including(recaptcha_annotation:),
            )
          end
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

        before do
          allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        end

        it 'tracks a valid submission' do
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
            success: true,
            failure_reason: nil,
            reauthentication: false,
          )

          expect(controller).to receive(:handle_valid_verification_for_authentication_context)
            .with(auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN)
            .and_call_original

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

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            context: 'authentication',
            multi_factor_auth_method: 'webauthn',
            success: true,
            enabled_mfa_methods_count: 1,
            webauthn_configuration_id: webauthn_configuration.id,
            multi_factor_auth_method_created_at: webauthn_configuration.created_at.strftime('%s%L'),
            new_device: true,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa,
          )
        end

        context 'with existing device' do
          before do
            allow(controller).to receive(:new_device?).and_return(false)
          end

          it 'tracks new device value' do
            expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
              mfa_device_type: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
              success: true,
              failure_reason: nil,
              reauthentication: false,
            )

            patch :confirm, params: params

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication',
              hash_including(new_device: false),
            )
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

          it 'tracks a valid submission' do
            expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
              mfa_device_type: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
              success: true,
              failure_reason: nil,
              reauthentication: false,
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

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication',
              context: 'authentication',
              multi_factor_auth_method: 'webauthn_platform',
              success: true,
              enabled_mfa_methods_count: 1,
              webauthn_configuration_id: webauthn_configuration.id,
              multi_factor_auth_method_created_at: webauthn_configuration.created_at
                .strftime('%s%L'),
              new_device: true,
              attempts: 1,
            )
            expect(@analytics).to have_logged_event(
              'User marked authenticated',
              authentication_type: :valid_2fa,
            )
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
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
          mfa_device_type: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
          success: false,
          failure_reason: { authenticator_data: [:invalid_authenticator_data] },
          reauthentication: false,
        )

        patch :confirm, params: params

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          context: 'authentication',
          multi_factor_auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
          success: false,
          error_details: { authenticator_data: { invalid_authenticator_data: true } },
          enabled_mfa_methods_count: 1,
          webauthn_configuration_id: webauthn_configuration.id,
          multi_factor_auth_method_created_at: webauthn_configuration.created_at.strftime('%s%L'),
          new_device: true,
          attempts: 1,
        )
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
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
            success: false,
            failure_reason: {
              authenticator_data: [:blank],
              client_data_json: [:blank],
              signature: [:blank],
              webauthn_configuration: [:blank],
              webauthn_error: [:present],
            },
            reauthentication: false,
          )

          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: false,
            error_details: {
              authenticator_data: { blank: true },
              client_data_json: { blank: true },
              signature: { blank: true },
              webauthn_configuration: { blank: true },
              webauthn_error: { present: true },
            },
            context: UserSessionContext::AUTHENTICATION_CONTEXT,
            enabled_mfa_methods_count: 2,
            multi_factor_auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
            multi_factor_auth_method_created_at:
              second_webauthn_platform_configuration.created_at.strftime('%s%L'),
            new_device: true,
            frontend_error: webauthn_error,
            attempts: 1,
          )
        end
      end
    end
  end
end
