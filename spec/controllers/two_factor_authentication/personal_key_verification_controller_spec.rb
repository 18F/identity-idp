require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PersonalKeyVerificationController,
               allowed_extra_analytics: [:*] do
  let(:personal_key) { { personal_key: 'foo' } }
  let(:payload) { { personal_key_form: personal_key } }

  describe '#show' do
    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'tracks the page visit' do
      user = build(:user, :with_personal_key, password: ControllerHelper::VALID_PASSWORD)
      stub_sign_in_before_2fa(user)
      stub_analytics
      analytics_hash = { context: 'authentication' }

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: enter personal key visited', analytics_hash)

      get :show
    end

    it 'redirects to the two_factor_options page if user is IAL2' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      PersonalKeyGenerator.new(user).create
      stub_sign_in_before_2fa(user)
      get :show

      expect(response.status).to eq(302)
      expect(response.location).to eq(authentication_methods_setup_url)
    end
  end

  describe '#create' do
    context 'when the user enters a valid personal key' do
      let(:user) { create(:user, :with_phone) }
      let(:personal_key) { { personal_key: PersonalKeyGenerator.new(user).create } }
      let(:payload) { { personal_key_form: personal_key } }
      it 'tracks the valid authentication event' do
        personal_key
        sign_in_before_2fa(user)
        stub_analytics

        analytics_hash = {
          success: true,
          errors: {},
          multi_factor_auth_method: 'personal-key',
          multi_factor_auth_method_created_at: user.reload.
            encrypted_recovery_code_digest_generated_at.strftime('%s%L'),
          new_device: nil,
        }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(analytics_hash)

        expect(@analytics).to receive(:track_event).with(
          'Personal key: Alert user about sign in',
          hash_including(emails: 1, sms_message_ids: ['fake-message-id']),
        )

        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        expect(controller).to receive(:handle_valid_verification_for_authentication_context).
          with(auth_method: TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY).
          and_call_original

        freeze_time do
          post :create, params: payload

          expect(subject.user_session[:auth_events]).to eq(
            [
              auth_method: TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY,
              at: Time.zone.now,
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
        end
      end

      context 'with enable_additional_mfa_redirect_for_personal_key_mfa? set to true' do
        before do
          personal_key
          sign_in_before_2fa(user)
          allow(FeatureManagement).
            to receive(:enable_additional_mfa_redirect_for_personal_key_mfa?).and_return(true)
        end
        it 'should redirect to mfa selection page' do
          post :create, params: payload
          expect(response).to redirect_to(authentication_methods_setup_url)
        end
      end

      context 'with enable_additional_mfa_redirect_for_personal_key_mfa? set to false' do
        before do
          personal_key
          sign_in_before_2fa(user)
          allow(FeatureManagement).
            to receive(:enable_additional_mfa_redirect_for_personal_key_mfa?).and_return(false)
        end
        it 'should redirect to account page' do
          post :create, params: payload
          expect(response).to redirect_to(account_path)
        end
      end
    end

    context 'with new device session value' do
      let(:user) { create(:user, :with_phone) }
      let(:personal_key) { { personal_key: PersonalKeyGenerator.new(user).create } }
      let(:payload) { { personal_key_form: personal_key } }

      it 'tracks new device value' do
        personal_key
        sign_in_before_2fa(user)
        stub_analytics
        subject.user_session[:new_device] = false
        analytics_hash = {
          success: true,
          errors: {},
          multi_factor_auth_method: 'personal-key',
          multi_factor_auth_method_created_at: user.reload.
            encrypted_recovery_code_digest_generated_at.strftime('%s%L'),
          new_device: false,
        }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(analytics_hash)

        freeze_time do
          post :create, params: payload
        end
      end
    end

    it 'does generate a new personal key after the user signs in with their old one' do
      user = create(:user)
      raw_key = PersonalKeyGenerator.new(user).create
      old_key = user.reload.encrypted_recovery_code_digest
      stub_sign_in_before_2fa(user)
      post :create, params: { personal_key_form: { personal_key: raw_key } }
      user.reload

      expect(user.encrypted_recovery_code_digest).to be_present
      expect(user.encrypted_recovery_code_digest).to_not eq old_key
    end

    it 'redirects to the two_factor_options page if user is IAL2' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      raw_key = PersonalKeyGenerator.new(user).create
      stub_sign_in_before_2fa(user)
      post :create, params: { personal_key_form: { personal_key: raw_key } }

      expect(response.status).to eq(302)
      expect(response.location).to eq(authentication_methods_setup_url)
    end

    context 'when the personal key field is empty' do
      let(:personal_key) { { personal_key: '' } }
      let(:payload) { { personal_key_form: personal_key } }

      before do
        user = create(:user, :with_personal_key, :with_phone, with: { phone: '+1 (703) 555-1212' })
        stub_sign_in_before_2fa(user)
      end

      it 'renders the show page' do
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_personal_key')
      end
    end

    context 'when the user enters an invalid personal key' do
      let(:user) do
        create(:user, :with_personal_key, :with_phone, with: { phone: '+1 (703) 555-1212' })
      end
      before do
        stub_sign_in_before_2fa(user)
      end

      it 'calls handle_invalid_otp' do
        expect(subject).to receive(:handle_invalid_otp).and_call_original

        post :create, params: payload

        expect(subject.user_session[:auth_events]).to eq nil
        expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
      end

      it 're-renders the personal key entry screen' do
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_personal_key')
      end

      it 'tracks the max attempts event' do
        user.second_factor_attempts_count =
          IdentityConfig.store.login_otp_confirmation_max_attempts - 1
        user.save
        personal_key_generated_at = controller.current_user.
          encrypted_recovery_code_digest_generated_at
        stub_analytics
        stub_attempts_tracker

        properties = {
          success: false,
          errors: { personal_key: [t('errors.messages.personal_key_incorrect')] },
          error_details: { personal_key: { personal_key_incorrect: true } },
          multi_factor_auth_method: 'personal-key',
          multi_factor_auth_method_created_at: personal_key_generated_at.strftime('%s%L'),
          new_device: nil,
        }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)
        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_rate_limited).
          with(mfa_device_type: 'personal_key')

        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        post :create, params: payload
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        post :create, params: payload
      end
    end

    it 'does not generate a new personal key if the user enters an invalid key' do
      user = create(:user, :with_personal_key)
      old_key = user.reload.encrypted_recovery_code_digest
      stub_sign_in_before_2fa(user)
      post :create, params: payload
      user.reload

      expect(user.encrypted_recovery_code_digest).to eq old_key
    end
  end
end
