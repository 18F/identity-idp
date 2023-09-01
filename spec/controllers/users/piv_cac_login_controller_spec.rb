require 'rails_helper'

RSpec.describe Users::PivCacLoginController do
  describe 'GET new' do
    before do
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'without a token' do
      before { get :new }

      it 'tracks the piv_cac setup' do
        expect(@analytics).to have_received(:track_event).with(
          'PIV CAC setup visited',
          in_account_creation_flow: false,
        )
      end

      it 'redirects to root url' do
        expect(response).to render_template(:new)
      end
    end

    context 'with a token' do
      let(:token) { 'TEST:abcdefg' }

      context 'an invalid token' do
        before { get :new, params: { token: token } }
        it 'tracks the login attempt' do
          expect(@analytics).to have_received(:track_event).with(
            'PIV/CAC Login',
            {
              errors: {},
              key_id: nil,
              success: false,
            },
          )
        end

        it 'redirects to the error url' do
          expect(response).to redirect_to(login_piv_cac_error_url(error: 'token.bad'))
        end
      end

      context 'with a valid token' do
        let(:service_provider) { create(:service_provider) }
        let(:sp_session) { { ial: 1, issuer: service_provider.issuer } }
        let(:nonce) { SecureRandom.base64(20) }
        let(:data) do
          {
            nonce: nonce,
            uuid: '1234',
            subject: 'subject',
            issuer: 'issuer',
          }.with_indifferent_access
        end

        before do
          subject.piv_session[:piv_cac_nonce] = nonce
          subject.session[:sp] = sp_session

          allow(PivCacService).to receive(:decode_token).with(token) { data }
          get :new, params: { token: token }
        end

        context 'without a valid user' do
          before do
            # valid_token? is being called twice, once to determine if it's a valid submission
            # and once to set the session variable in process_invalid_submission
            # good opportunity for a refactor
            expect(PivCacService).to have_received(:decode_token).with(token) { data }.twice
          end

          it 'tracks the login attempt' do
            expect(@analytics).to have_received(:track_event).with(
              'PIV/CAC Login',
              {
                errors: {
                  type: 'user.not_found',
                },
                key_id: nil,
                success: false,
              },
            )
          end

          it 'sets the session variable' do
            expect(subject.session[:needs_to_setup_piv_cac_after_sign_in]).to be true
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

          before do
            expect(PivCacService).to have_received(:decode_token).with(token) { data }
            sign_in user
          end

          it 'tracks the login attempt' do
            expect(@analytics).to have_received(:track_event).with(
              'PIV/CAC Login',
              {
                errors: {},
                key_id: nil,
                success: true,
              },
            )
          end

          it 'sets the session correctly' do
            expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).
              to eq false

            expect(controller.user_session[:authn_at]).to_not be nil
            expect(controller.user_session[:authn_at].class).to eq ActiveSupport::TimeWithZone
          end

          it 'tracks the user_marked_authed event' do
            expect(@analytics).to have_received(:track_event).with(
              'User marked authenticated',
              { authentication_type: :piv_cac },
            )
          end

          it 'saves the piv_cac session information' do
            session_info = {
              subject: data[:subject],
              issuer: data[:issuer],
              presented: true,
            }
            expect(controller.user_session[:decrypted_x509]).to eq session_info.to_json
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
              expect(@analytics).to have_received(:track_event).with(
                'User marked authenticated',
                { authentication_type: :valid_2fa },
              )
            end

            context 'ial1 user' do
              it 'redirects to the after_sign_in_path_for' do
                expect(response).to redirect_to(account_url)
              end

              context 'ial_max service level' do
                let(:sp_session) do
                  { ial: Idp::Constants::IAL_MAX, issuer: service_provider.issuer }
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
                let(:sp_session) { { ial: Idp::Constants::IAL2, issuer: service_provider.issuer } }

                it 'redirects to the capture_password_url' do
                  expect(response).to redirect_to(capture_password_url)
                end
              end

              context 'ial_max service_level' do
                let(:sp_session) do
                  { ial: Idp::Constants::IAL_MAX, issuer: service_provider.issuer }
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
