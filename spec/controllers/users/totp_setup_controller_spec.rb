require 'rails_helper'

describe Users::TotpSetupController, devise: true do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
      )
    end
  end

  describe '#new' do
    context 'user is setting up authenticator app after account creation' do
      before do
        stub_analytics
        user = build(:user, :signed_up, :with_phone, with: { phone: '703-555-1212' })
        stub_sign_in(user)
        allow(@analytics).to receive(:track_event)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with UserDecorator#qrcode' do
        expect(
          subject.current_user.decorate.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        properties = {
          user_signed_up: true,
          totp_secret_present: true,
          enabled_mfa_methods_count: 1,
        }

        expect(@analytics).
          to have_received(:track_event).with('TOTP Setup Visited', properties)
      end
    end

    context 'user is setting up authenticator app during account creation' do
      before do
        stub_analytics
        stub_sign_in_before_2fa
        allow(@analytics).to receive(:track_event)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with UserDecorator#qrcode' do
        expect(
          subject.current_user.decorate.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        properties = {
          user_signed_up: false,
          totp_secret_present: true,
          enabled_mfa_methods_count: 0,
        }

        expect(@analytics).
          to have_received(:track_event).with('TOTP Setup Visited', properties)
      end
    end
  end

  describe '#confirm' do
    let(:name) { SecureRandom.hex }

    context 'user is already signed up' do
      context 'when user presents invalid code' do
        before do
          user = build(:user, personal_key: 'ABCD-DEFG-HIJK-LMNO')
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          result = {
            success: false,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            enabled_mfa_methods_count: 0,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: false)
        end
      end

      context 'when user presents correct code' do
        before do
          user = create(:user, :signed_up)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { name: name, code: generate_totp_code(secret) }
        end

        it 'redirects to account_path with a success message' do
          expect(response).to redirect_to(account_path)
          expect(subject.user_session[:new_totp_secret]).to be_nil

          result = {
            success: true,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: next_auth_app_id,
            enabled_mfa_methods_count: 2,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: true)
        end
      end

      context 'when user presents nil code' do
        before do
          user = create(:user, :signed_up)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { name: name }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          result = {
            success: false,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            enabled_mfa_methods_count: 1,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: false)
        end
      end

      context 'when user omits name' do
        before do
          user = create(:user, :signed_up)
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { code: generate_totp_code(secret) }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          result = {
            success: false,
            error_details: { name: [:blank] },
            errors: { name: [t('errors.messages.blank')] },
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            enabled_mfa_methods_count: 1,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: false)
        end
      end
    end

    context 'user is not yet signed up' do
      context 'when user presents invalid code' do
        before do
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          result = {
            success: false,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            enabled_mfa_methods_count: 0,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }
          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: false)
        end
      end

      context 'when user presents correct code' do
        let(:mfa_selections) { ['auth_app'] }
        before do
          secret = ROTP::Base32.random_base32
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret
          subject.user_session[:mfa_selections] = mfa_selections
          allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true

          patch :confirm, params: { name: name, code: generate_totp_code(secret) }
        end

        context 'when user selected only one method on account creation' do
          it 'redirects to auth method confirmation path with a success message' do
            expect(response).to redirect_to(auth_method_confirmation_path)
            expect(subject.user_session[:new_totp_secret]).to be_nil

            result = {
              success: true,
              errors: {},
              totp_secret_present: true,
              multi_factor_auth_method: 'totp',
              auth_app_configuration_id: next_auth_app_id,
              enabled_mfa_methods_count: 1,
              in_multi_mfa_selection_flow: true,
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
            }

            expect(@analytics).to have_received(:track_event).
              with('Multi-Factor Authentication Setup', result)

            expect(@irs_attempts_api_tracker).to have_received(:track_event).
              with(:mfa_enroll_totp, success: true)
          end
        end

        context 'when user has multiple MFA methods left in user session' do
          let(:mfa_selections) { ['auth_app', 'voice'] }

          it 'redirects to next mfa path with a success message and still logs analytics' do
            expect(response).to redirect_to(phone_setup_url)

            result = {
              success: true,
              errors: {},
              totp_secret_present: true,
              multi_factor_auth_method: 'totp',
              auth_app_configuration_id: next_auth_app_id,
              enabled_mfa_methods_count: 1,
              in_multi_mfa_selection_flow: true,
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
            }

            expect(@analytics).to have_received(:track_event).
              with('Multi-Factor Authentication Setup', result)

            expect(@irs_attempts_api_tracker).to have_received(:track_event).
              with(:mfa_enroll_totp, success: true)
          end
        end
      end

      context 'when totp secret is no longer in user_session' do
        before do
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(:track_event)

          patch :confirm, params: { name: name, code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.auth_app_configurations.any?).to eq false

          result = {
            success: false,
            errors: {},
            totp_secret_present: false,
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            enabled_mfa_methods_count: 0,
            in_multi_mfa_selection_flow: false,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(@analytics).to have_received(:track_event).
            with('Multi-Factor Authentication Setup', result)

          expect(@irs_attempts_api_tracker).to have_received(:track_event).
            with(:mfa_enroll_totp, success: false)
        end
      end
    end
  end

  describe '#disable' do
    context 'when a user has configured TOTP' do
      it 'disables TOTP' do
        user = create(:user, :signed_up, :with_phone)
        totp_app = user.auth_app_configurations.create(otp_secret_key: 'foo', name: 'My Auth App')
        user.save
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
        allow(subject).to receive(:create_user_event)

        delete :disable, params: { id: totp_app.id }

        expect(user.reload.auth_app_configurations.any?).to eq false
        expect(response).to redirect_to(account_two_factor_authentication_path)
        expect(flash[:success]).to eq t('notices.totp_disabled')
        expect(@analytics).to have_received(:track_event).with('TOTP: User Disabled')
        expect(subject).to have_received(:create_user_event).with(:authenticator_disabled)
      end
    end

    context 'when totp is the last mfa method' do
      it 'does not disable totp' do
        user = create(:user, :with_authentication_app)
        sign_in user

        delete :disable
        expect(response).to redirect_to(account_two_factor_authentication_path)
        expect(user.reload.auth_app_configurations.any?).to eq true
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
