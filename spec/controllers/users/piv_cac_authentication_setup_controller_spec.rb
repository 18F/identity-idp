require 'rails_helper'

RSpec.describe Users::PivCacAuthenticationSetupController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
        :confirm_recently_authenticated_2fa,
      )
    end
  end

  describe '#new' do
    let(:params) { nil }
    subject(:response) { get :new, params: params }

    context 'when signed out' do
      it 'redirects to sign in page' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when signing in' do
      before { stub_sign_in_before_2fa(user) }

      let(:user) do
        create(:user, :fully_registered, :with_piv_or_cac, with: { phone: '+1 (703) 555-0000' })
      end

      it 'redirects to 2fa entry' do
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    context 'when signed in' do
      let(:user) { create(:user, :fully_registered) }
      before { stub_sign_in(user) }

      it 'assigns piv_cac_required instance variable as false' do
        response

        expect(assigns(:piv_cac_required)).to eq(false)
      end

      context 'when SP requires PIV/CAC' do
        let(:service_provider) { create(:service_provider) }

        before do
          controller.session[:sp] = {
            issuer: service_provider.issuer,
            acr_values: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          }
        end

        it 'assigns piv_cac_required instance variable as true' do
          response

          expect(assigns(:piv_cac_required)).to eq(true)
        end
      end

      context 'without associated piv/cac' do
        let(:user) do
          create(:user, :fully_registered, with: { phone: '+1 (703) 555-0000' })
        end
        let(:nickname) { 'Card 1' }

        before(:each) do
          allow(PivCacService).to receive(:decode_token).with(good_token) { good_token_response }
          allow(PivCacService).to receive(:decode_token).with(bad_token) { bad_token_response }
          allow(controller).to receive(:user_session).and_return(piv_cac_nonce: nonce)
          controller.user_session[:piv_cac_nickname] = nickname
        end

        let(:nonce) { 'nonce' }

        let(:good_token) { 'good-token' }
        let(:good_token_response) do
          {
            'subject' => 'some dn',
            'uuid' => 'some-random-string',
            'nonce' => nonce,
          }
        end

        let(:bad_token) { 'bad-token' }
        let(:bad_token_response) do
          {
            'error' => 'certificate.bad',
            'nonce' => nonce,
          }
        end

        context 'when rendered without a token' do
          it 'renders the "new" template' do
            expect(response).to render_template(:new)
          end

          it 'tracks the analytic event of visited' do
            stub_analytics

            response

            expect(@analytics).to have_logged_event(
              :piv_cac_setup_visited,
              in_account_creation_flow: false,
              enabled_mfa_methods_count: 1,
            )
          end
        end

        context 'when redirected with a good token' do
          let(:params) { { token: good_token } }
          let(:user) { create(:user) }
          let(:mfa_selections) { ['piv_cac', 'voice'] }

          before do
            controller.user_session[:mfa_selections] = mfa_selections
          end

          context 'with no additional MFAs chosen on setup' do
            let(:mfa_selections) { ['piv_cac'] }
            it 'redirects to suggest 2nd MFA page' do
              stub_analytics

              expect(response).to redirect_to(auth_method_confirmation_url)

              expect(@analytics).to have_logged_event(
                'Multi-Factor Authentication Setup',
                enabled_mfa_methods_count: 1,
                errors: {},
                multi_factor_auth_method: 'piv_cac',
                in_account_creation_flow: false,
                success: true,
                attempts: 1,
              )
            end

            it 'logs mfa attempts commensurate to number of attempts' do
              stub_analytics

              get :new, params: { token: bad_token }
              response

              expect(@analytics).to have_logged_event(
                'Multi-Factor Authentication Setup',
                enabled_mfa_methods_count: 1,
                errors: {},
                multi_factor_auth_method: 'piv_cac',
                in_account_creation_flow: false,
                success: true,
                attempts: 2,
              )
            end

            it 'sets the piv/cac session information' do
              response

              json = {
                'subject' => 'some dn',
                'issuer' => nil,
                'presented' => true,
              }.to_json

              expect(controller.user_session[:decrypted_x509]).to eq json
            end

            it 'sets the session to not require piv setup upon sign-in' do
              response

              expect(controller.session[:needs_to_setup_piv_cac_after_sign_in]).to eq false
            end

            context 'when user adds after piv cac mismatch error' do
              before do
                controller.user_session[:add_piv_cac_after_2fa] = true
              end

              it 'deletes add_piv_cac_after_2fa session value' do
                response

                expect(controller.user_session).not_to have_key(:add_piv_cac_after_2fa)
              end
            end
          end

          context 'with additional MFAs leftover' do
            it 'redirects to Mfa Confirmation page' do
              expect(response).to redirect_to(phone_setup_url)
            end

            it 'sets the piv/cac session information' do
              response

              json = {
                'subject' => 'some dn',
                'issuer' => nil,
                'presented' => true,
              }.to_json

              expect(controller.user_session[:decrypted_x509]).to eq json
            end

            it 'sets the session to not require piv setup upon sign-in' do
              response

              expect(controller.session[:needs_to_setup_piv_cac_after_sign_in]).to eq false
            end
          end
        end

        context 'when redirected with an error token' do
          let(:params) { { token: bad_token } }

          it 'renders the error template' do
            expect(response).to redirect_to setup_piv_cac_error_path(error: 'certificate.bad')
          end

          it 'resets the piv/cac session information' do
            response

            expect(controller.user_session[:decrypted_x509]).to be_nil
          end
        end
      end
    end
  end

  describe '#submit_new_piv_cac' do
    let(:user) { create(:user, :fully_registered) }

    before { stub_sign_in(user) }

    context 'when user opts to skip adding piv cac after 2fa' do
      subject(:response) { post :submit_new_piv_cac, params: { skip: 'true' } }

      before do
        allow(controller).to receive(:user_session).and_return(add_piv_cac_after_2fa: true)
      end

      it 'deletes add_piv_cac_after_2fa session value' do
        response

        expect(controller.user_session).not_to have_key(:add_piv_cac_after_2fa)
      end

      it 'redirects to after sign in path' do
        expect(response).to redirect_to(account_path)
      end
    end
  end
end
