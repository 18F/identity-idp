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
    context 'when not signed in' do
      it 'redirects to root url' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when signed out' do
      it 'redirects to sign in page' do
        get :new

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when signing in' do
      before { stub_sign_in_before_2fa(user) }

      let(:user) do
        create(:user, :fully_registered, :with_piv_or_cac, with: { phone: '+1 (703) 555-0000' })
      end

      it 'redirects to 2fa entry' do
        get :new

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    context 'when signed in' do
      before { stub_sign_in(user) }

      context 'without associated piv/cac' do
        let(:user) do
          create(:user, :fully_registered, with: { phone: '+1 (703) 555-0000' })
        end
        let(:nickname) { 'Card 1' }

        before(:each) do
          allow(PivCacService).to receive(:decode_token).with(good_token) { good_token_response }
          allow(PivCacService).to receive(:decode_token).with(bad_token) { bad_token_response }
          allow(subject).to receive(:user_session).and_return(piv_cac_nonce: nonce)
          subject.user_session[:piv_cac_nickname] = nickname
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
            get :new
            expect(response).to render_template(:new)
          end

          it 'tracks the analytic event of visited' do
            stub_analytics

            get :new

            expect(@analytics).to have_logged_event(
              :piv_cac_setup_visited,
              in_account_creation_flow: false,
              enabled_mfa_methods_count: 1,
            )
          end
        end

        context 'when redirected with a good token' do
          let(:user) do
            create(:user)
          end
          let(:mfa_selections) { ['piv_cac', 'voice'] }
          before do
            subject.user_session[:mfa_selections] = mfa_selections
          end

          context 'with no additional MFAs chosen on setup' do
            let(:mfa_selections) { ['piv_cac'] }
            it 'redirects to suggest 2nd MFA page' do
              get :new, params: { token: good_token }
              expect(response).to redirect_to(auth_method_confirmation_url)
            end

            it 'sets the piv/cac session information' do
              get :new, params: { token: good_token }
              json = {
                'subject' => 'some dn',
                'issuer' => nil,
                'presented' => true,
              }.to_json

              expect(subject.user_session[:decrypted_x509]).to eq json
            end

            it 'sets the session to not require piv setup upon sign-in' do
              get :new, params: { token: good_token }

              expect(subject.session[:needs_to_setup_piv_cac_after_sign_in]).to eq false
            end
          end

          context 'with additional MFAs leftover' do
            it 'redirects to Mfa Confirmation page' do
              get :new, params: { token: good_token }
              expect(response).to redirect_to(phone_setup_url)
            end

            it 'sets the piv/cac session information' do
              get :new, params: { token: good_token }
              json = {
                'subject' => 'some dn',
                'issuer' => nil,
                'presented' => true,
              }.to_json

              expect(subject.user_session[:decrypted_x509]).to eq json
            end

            it 'sets the session to not require piv setup upon sign-in' do
              get :new, params: { token: good_token }

              expect(subject.session[:needs_to_setup_piv_cac_after_sign_in]).to eq false
            end
          end
        end

        context 'when redirected with an error token' do
          it 'renders the error template' do
            get :new, params: { token: bad_token }
            expect(response).to redirect_to setup_piv_cac_error_path(error: 'certificate.bad')
          end

          it 'resets the piv/cac session information' do
            expect(subject.user_session[:decrypted_x509]).to be_nil
          end
        end
      end
    end
  end
end
