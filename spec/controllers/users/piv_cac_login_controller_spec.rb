require 'rails_helper'

RSpec.describe Users::PivCacLoginController do
  describe 'GET new' do
    let(:user) {}

    before do
      stub_analytics(user:)
    end

    context 'without a token' do
      before { get :new }

      it 'tracks the piv cac login' do
        expect(@analytics).to have_logged_event(:piv_cac_login_visited)
      end

      it 'redirects to root url' do
        expect(response).to render_template(:new)
      end
    end

    context 'with a token' do
      let(:token) { 'TEST:abcdefg' }

      context 'an invalid token' do
        subject(:response) { get :new, params: { token: token } }

        it 'tracks the login attempt' do
          response

          expect(@analytics).to have_logged_event(
            :piv_cac_login,
            success: false,
          )
        end

        it 'redirects to the error url' do
          expect(response).to redirect_to(login_piv_cac_error_url(error: 'token.bad'))
        end
      end

      context 'with a valid token' do
        let(:service_provider) { create(:service_provider) }
        let(:acr_values) { Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF }
        let(:sp_session) { { ial: 1, issuer: service_provider.issuer, acr_values: } }
        let(:nonce) { SecureRandom.base64(20) }
        let(:data) do
          {
            nonce: nonce,
            uuid: '1234',
            subject: 'subject',
            issuer: 'issuer',
          }.with_indifferent_access
        end

        subject(:response) { get :new, params: { token: } }

        before do
          controller.piv_session[:piv_cac_nonce] = nonce
          controller.session[:sp] = sp_session

          allow(PivCacService).to receive(:decode_token).with(token) { data }
        end

        context 'without a valid user' do
          it 'calls decode_token twice' do
            response

            # valid_token? is being called twice, once to determine if it's a valid submission
            # and once to set the session variable in process_invalid_submission
            # good opportunity for a refactor
            expect(PivCacService).to have_received(:decode_token).with(token) { data }.twice
          end

          it 'tracks the login attempt' do
            response

            expect(@analytics).to have_logged_event(
              :piv_cac_login,
              errors: {
                type: 'user.not_found',
              },
              success: false,
            )
          end

          it 'sets the session variable' do
            response

            expect(controller.session[:needs_to_setup_piv_cac_after_sign_in]).to be true
          end

          it 'redirects to the error url' do
            expect(response).to redirect_to(login_piv_cac_error_url(error: 'user.not_found'))
          end
        end

        context 'with a valid user' do
          let(:user) { build(:user) }
          let(:piv_cac_config) { create(:piv_cac_configuration, user: user) }
          let(:data) do
            {
              nonce: nonce,
              uuid: piv_cac_config.x509_dn_uuid,
              subject: 'subject',
              issuer: 'issuer',
            }.with_indifferent_access
          end

          it 'calls decode_token' do
            response

            expect(PivCacService).to have_received(:decode_token).with(token) { data }
          end

          it 'tracks the login attempt' do
            response

            expect(@analytics).to have_logged_event(
              :piv_cac_login,
              success: true,
              new_device: true,
            )
          end

          it 'sets the session correctly' do
            response

            expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION])
              .to eq false
            expect(controller.auth_methods_session.auth_events).to match(
              [
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
                  at: kind_of(ActiveSupport::TimeWithZone),
                },
              ],
            )
          end

          it 'sets and then unsets new device session value' do
            expect(controller).to receive(:set_new_device_session).with(nil).ordered
            expect(controller).to receive(:set_new_device_session).with(false).ordered

            response
          end

          it 'tracks the user_marked_authed event' do
            response

            expect(@analytics).to have_logged_event(
              'User marked authenticated',
              authentication_type: :valid_2fa,
            )
          end

          it 'saves the piv_cac session information' do
            response

            session_info = {
              subject: data[:subject],
              issuer: data[:issuer],
              presented: true,
            }
            expect(controller.user_session[:decrypted_x509]).to eq session_info.to_json
          end

          context 'with authenticated device' do
            let(:user) { create(:user, :with_authenticated_device) }

            before do
              cookies[:device] = user.devices.last.cookie_uuid
            end

            it 'tracks the login attempt' do
              response

              expect(@analytics).to have_logged_event(
                :piv_cac_login,
                success: true,
                new_device: false,
              )
            end
          end

          context 'when the user has not accepted the most recent terms of use' do
            let(:user) do
              build(:user, accepted_terms_at: IdentityConfig.store.rules_of_use_updated_at - 1.year)
            end

            it 'redirects to rules_of_use_path' do
              expect(response).to redirect_to rules_of_use_path
            end
          end

          describe 'it handles the otp_context' do
            it 'tracks the user_marked_authed event' do
              response

              expect(@analytics).to have_logged_event(
                'User marked authenticated',
                authentication_type: :valid_2fa,
              )
            end

            context 'ial1 user' do
              it 'redirects to the after_sign_in_path_for' do
                expect(response).to redirect_to(account_url)
              end

              context 'ial2 service_level' do
                let(:sp_session) do
                  {
                    acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                    issuer: service_provider.issuer,
                  }
                end

                it 'redirects to account' do
                  expect(response).to redirect_to(account_url)
                end
              end

              context 'ial_max service level' do
                let(:sp_session) do
                  { ial: Idp::Constants::IAL_MAX, issuer: service_provider.issuer, acr_values: }
                end

                it 'redirects to the after_sign_in_path_for' do
                  expect(response).to redirect_to(account_url)
                end
              end
            end

            context 'ial2 user' do
              let(:user) { create(:user, profiles: [create(:profile, :verified, :active)]) }

              context 'ial1 service level' do
                it 'redirects to the after_sign_in_path_for' do
                  expect(response).to redirect_to(account_url)
                end
              end

              context 'ial2 service_level' do
                let(:sp_session) do
                  {
                    acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                    issuer: service_provider.issuer,
                  }
                end

                it 'redirects to the capture_password_url' do
                  expect(response).to redirect_to(capture_password_url)
                end
              end

              context 'ial_max service_level' do
                let(:sp_session) do
                  {
                    acr_values: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                    issuer: service_provider.issuer,
                  }
                end

                it 'redirects to the capture_password_url' do
                  expect(response).to redirect_to(capture_password_url)
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'GET error' do
    before { get :error, params: { error: 'token.bad' } }

    it 'sends the error to the error presenter' do
      expect(assigns(:presenter).error).to eq 'token.bad'
    end
  end
end
