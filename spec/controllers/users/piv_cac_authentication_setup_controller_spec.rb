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

  describe 'when not signed in' do
    describe 'GET index' do
      it 'redirects to root url' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    describe 'DELETE delete' do
      it 'redirects to root url' do
        delete :delete

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when signed out' do
    describe 'GET index' do
      it 'redirects to sign in page' do
        get :new

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  describe 'when signing in' do
    before(:each) { stub_sign_in_before_2fa(user) }
    let(:user) do
      create(:user, :fully_registered, :with_piv_or_cac, with: { phone: '+1 (703) 555-0000' })
    end

    describe 'GET index' do
      it 'redirects to 2fa entry' do
        get :new
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    describe 'DELETE delete' do
      it 'redirects to root url' do
        delete :delete
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end
  end

  describe 'when signed in' do
    before(:each) { stub_sign_in(user) }

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
        subject.user_session[:authn_at] = Time.zone.now
        subject.user_session[:auth_method] = TwoFactorAuthenticatable::AuthMethod::SMS
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

      describe 'GET index' do
        context 'when rendered without a token' do
          it 'renders the "new" template' do
            get :new
            expect(response).to render_template(:new)
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
              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:track_event).with(
                :mfa_enroll_piv_cac,
                success: true,
                subject_dn: 'some dn',
                failure_reason: nil,
              )

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
              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:track_event).with(
                :mfa_enroll_piv_cac,
                success: true,
                subject_dn: 'some dn',
                failure_reason: nil,
              )

              get :new, params: { token: good_token }

              expect(subject.session[:needs_to_setup_piv_cac_after_sign_in]).to eq false
            end
          end

          context 'with additional MFAs leftover' do
            it 'redirects to Mfa Confirmation page' do
              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:track_event).with(
                :mfa_enroll_piv_cac,
                success: true,
                subject_dn: 'some dn',
                failure_reason: nil,
              )

              get :new, params: { token: good_token }
              expect(response).to redirect_to(phone_setup_url)
            end

            it 'sets the piv/cac session information' do
              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:track_event).with(
                :mfa_enroll_piv_cac,
                success: true,
                subject_dn: 'some dn',
                failure_reason: nil,
              )

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
            stub_attempts_tracker
            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :mfa_enroll_piv_cac,
              success: false,
              subject_dn: nil,
              failure_reason: { type: 'certificate.bad' },
            )

            get :new, params: { token: bad_token }
            expect(response).to redirect_to setup_piv_cac_error_path(error: 'certificate.bad')
          end

          it 'resets the piv/cac session information' do
            expect(subject.user_session[:decrypted_x509]).to be_nil
          end
        end
      end

      describe 'DELETE delete' do
        it 'redirects to account 2FA page' do
          delete :delete
          expect(response).to redirect_to(account_two_factor_authentication_path)
        end
      end
    end

    context 'with associated piv/cac' do
      let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

      describe 'GET index' do
        it 'does not redirect to account page because we allow multiple PIV/CACs' do
          get :new
          expect(response).to render_template(:new)
        end
      end

      describe 'DELETE delete' do
        let(:piv_cac_configuration_id) { user.piv_cac_configurations.first.id }

        it 'redirects to account page' do
          delete :delete, params: { id: piv_cac_configuration_id }
          expect(response).to redirect_to(account_two_factor_authentication_path)
        end

        it 'removes the piv/cac association' do
          delete :delete, params: { id: piv_cac_configuration_id }
          expect(user.reload.piv_cac_configurations).to be_empty
        end

        it 'sends a recovery information changed event' do
          expect(PushNotification::HttpPush).to receive(:deliver).
            with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
          delete :delete, params: { id: piv_cac_configuration_id }
        end

        it 'resets the remember device revocation date/time' do
          expect(user.remember_device_revoked_at).to eq nil
          freeze_time do
            delete :delete, params: { id: piv_cac_configuration_id }
            expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
          end
        end

        it 'removes the piv/cac information from the user session' do
          subject.user_session[:decrypted_x509] = {}
          delete :delete, params: { id: piv_cac_configuration_id }
          expect(subject.user_session[:decrypted_x509]).to be_nil
        end

        it 'does not remove the piv/cac association if it is the last mfa method' do
          user.phone_configurations.destroy_all
          user.backup_code_configurations.destroy_all

          delete :delete, params: { id: piv_cac_configuration_id }

          expect(response).to redirect_to(account_two_factor_authentication_path)
          expect(user.reload.piv_cac_configurations.first.x509_dn_uuid).to_not be_nil
        end
      end
    end
  end
end
