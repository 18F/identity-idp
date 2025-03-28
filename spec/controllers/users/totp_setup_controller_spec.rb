require 'rails_helper'

RSpec.describe Users::TotpSetupController, devise: true do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
        :confirm_recently_authenticated_2fa,
      )
    end
  end

  describe '#new' do
    context 'user is setting up authenticator app after account creation' do
      before do
        stub_analytics
        user = create(:user, :fully_registered, :with_phone, with: { phone: '703-555-1212' })
        stub_sign_in(user)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with User#qrcode' do
        expect(
          subject.current_user.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        expect(@analytics).to have_logged_event(
          'TOTP Setup Visited',
          user_signed_up: true,
          totp_secret_present: true,
          enabled_mfa_methods_count: 1,
          in_account_creation_flow: false,
        )
      end
    end

    context 'user is setting up authenticator app during account creation' do
      before do
        user = create(:user)
        stub_analytics
        stub_sign_in_before_2fa(user)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with User#qrcode' do
        expect(
          subject.current_user.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        expect(@analytics).to have_logged_event(
          'TOTP Setup Visited',
          user_signed_up: false,
          totp_secret_present: true,
          enabled_mfa_methods_count: 0,
          in_account_creation_flow: false,
        )
      end
    end
  end

  describe '#confirm' do
    let(:name) { SecureRandom.hex }
    let(:success) { false }

    before do
      stub_analytics
      stub_attempts_tracker
      expect(@attempts_api_tracker).to receive(:mfa_enroll_totp).with(success:)
    end

    context 'user is already signed up' do
      context 'when user presents invalid code' do
        before do
          user = build(:user, personal_key: 'ABCD-DEFG-HIJK-LMNO')
          stub_sign_in(user)
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: false,
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            enabled_mfa_methods_count: 0,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end

      context 'when user presents correct code' do
        let(:success) { true }
        before do
          user = create(:user, :fully_registered)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { name: name, code: generate_totp_code(secret) }
        end

        it 'redirects to account_path with a success message' do
          expect(response).to redirect_to(account_path)
          expect(subject.user_session[:new_totp_secret]).to be_nil

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: true,
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: next_auth_app_id,
            enabled_mfa_methods_count: 2,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end

      context 'when user presents correct code after submitting an incorrect code' do
        let(:success) { false }
        before do
          user = create(:user, :fully_registered)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)

          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { name: name, code: 123 }

          subject.user_session[:new_totp_secret] = secret

          # calls the tracker again with success: true
          expect(@attempts_api_tracker).to receive(:mfa_enroll_totp).with(success: true)
          patch :confirm, params: { name: name, code: generate_totp_code(secret) }
        end

        it 'logs correct events' do
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: true,
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: next_auth_app_id,
            enabled_mfa_methods_count: 2,
            in_account_creation_flow: false,
            attempts: 2,
          )
        end
      end

      context 'when user presents nil code' do
        before do
          user = create(:user, :fully_registered)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { name: name }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: false,
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end

      context 'when user omits name' do
        before do
          user = create(:user, :fully_registered)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { code: generate_totp_code(secret) }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: false,
            error_details: { name: { blank: true } },
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end
    end

    context 'user is not yet signed up' do
      context 'when user presents invalid code' do
        before do
          stub_sign_in_before_2fa
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: false,
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            enabled_mfa_methods_count: 0,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end

      context 'when user presents correct code' do
        let(:mfa_selections) { ['auth_app'] }
        before do
          secret = ROTP::Base32.random_base32
          stub_sign_in_before_2fa
          subject.user_session[:new_totp_secret] = secret
          subject.user_session[:mfa_selections] = mfa_selections
          subject.user_session[:in_account_creation_flow] = true

          patch :confirm, params: { name: name, code: generate_totp_code(secret) }
        end

        context 'when user selected only one method on account creation' do
          let(:success) { true }
          it 'redirects to auth method confirmation path with a success message' do
            expect(response).to redirect_to(auth_method_confirmation_path)
            expect(subject.user_session[:new_totp_secret]).to be_nil

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication Setup',
              success: true,
              totp_secret_present: true,
              multi_factor_auth_method: 'totp',
              auth_app_configuration_id: next_auth_app_id,
              enabled_mfa_methods_count: 1,
              in_account_creation_flow: true,
              attempts: 1,
            )
          end
        end

        context 'when user has multiple MFA methods left in user session' do
          let(:mfa_selections) { ['auth_app', 'voice'] }
          let(:success) { true }

          it 'redirects to next mfa path with a success message and still logs analytics' do
            expect(response).to redirect_to(phone_setup_url)

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication Setup',
              success: true,
              totp_secret_present: true,
              multi_factor_auth_method: 'totp',
              auth_app_configuration_id: next_auth_app_id,
              enabled_mfa_methods_count: 1,
              in_account_creation_flow: true,
              attempts: 1,
            )
          end
        end
      end

      context 'when totp secret is no longer in user_session' do
        before do
          stub_sign_in_before_2fa

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            success: false,
            totp_secret_present: false,
            multi_factor_auth_method: 'totp',
            enabled_mfa_methods_count: 0,
            in_account_creation_flow: false,
            attempts: 1,
          )
        end
      end
    end
  end

  def next_auth_app_id
    recs = ActiveRecord::Base.connection.execute(
      "SELECT NEXTVAL(pg_get_serial_sequence('auth_app_configurations', 'id')) AS new_id",
    )
    recs[0]['new_id'] - 1
  end
end
