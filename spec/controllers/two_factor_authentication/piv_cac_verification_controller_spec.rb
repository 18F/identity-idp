require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacVerificationController do
  let(:user) do
    create(
      :user, :fully_registered, :with_piv_or_cac,
      with: { phone: '+1 (703) 555-0000' }
    )
  end

  let(:nonce) { 'once' }

  let(:x509_subject) { 'o=US, ou=DoD, cn=John.Doe.1234' }
  let(:x509_issuer) do
    '/C=US/O=Entrust/OU=Certification Authorities/OU=Entrust Managed Services SSP CA'
  end
  let(:bad_dn) { 'bad-dn' }

  before(:each) do
    session_info = { piv_cac_nonce: nonce }
    allow(controller).to receive(:user_session).and_return(session_info)
    allow(PivCacService).to receive(:decode_token).with('good-token').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid,
      'subject' => x509_subject,
      'issuer' => x509_issuer,
      'nonce' => nonce,
      'key_id' => 'foo',
    )
    allow(PivCacService).to receive(:decode_token).with('good-other-token').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid + 'X',
      'subject' => x509_subject + 'X',
      'issuer' => x509_issuer,
      'nonce' => nonce,
      'key_id' => 'foo',
    )
    allow(PivCacService).to receive(:decode_token).with('bad-token').and_return(
      'error' => 'token.bad',
    )
    allow(PivCacService).to receive(:decode_token).with('bad-nonce').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid,
      'subject' => x509_subject,
      'issuer' => x509_issuer,
      'nonce' => 'bad-' + nonce,
      'key_id' => 'foo',
    )
  end

  describe '#show' do
    context 'before the user presents a valid PIV/CAC' do
      before(:each) do
        stub_sign_in_before_2fa(user)
      end

      it 'renders a page with a submit button to capture the cert' do
        get :show

        expect(response).to render_template(:show)
      end

      it 'logs the visit event' do
        stub_analytics

        get :show

        expect(@analytics).to have_logged_event(
          :multi_factor_auth_enter_piv_cac,
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          new_device: true,
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

          stub_analytics

          get :show

          expect(@analytics).to have_logged_event(
            :multi_factor_auth_enter_piv_cac,
            hash_including(recaptcha_annotation:),
          )
        end
      end
    end

    context 'when the user presents a valid PIV/CAC' do
      before(:each) do
        stub_sign_in_before_2fa(user)
      end

      it 'redirects to the profile' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        freeze_time do
          get :show, params: { token: 'good-token' }

          expect(subject.user_session[:auth_events]).to eq(
            [
              auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
              at: Time.zone.now,
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
          expect(response).to redirect_to account_path
          expect(subject.user_session[:decrypted_x509]).to eq(
            {
              'subject' => x509_subject,
              'issuer' => x509_issuer,
              'presented' => true,
            }.to_json,
          )
        end
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update!(second_factor_attempts_count: 1)

        get :show, params: { token: 'good-token' }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        cfg = controller.current_user.piv_cac_configurations.first
        stub_attempts_tracker

        expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
          mfa_device_type: 'piv_cac',
          success: true,
          failure_reason: nil,
          reauthentication: false,
        )

        expect(controller).to receive(:handle_valid_verification_for_authentication_context)
          .with(auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC)
          .and_call_original

        get :show, params: { token: 'good-token' }

        expect(@analytics).not_to have_logged_event(:multi_factor_auth_enter_piv_cac)
        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          success: true,
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          new_device: true,
          enabled_mfa_methods_count: 2,
          multi_factor_auth_method_created_at: cfg.created_at.strftime('%s%L'),
          piv_cac_configuration_id: cfg.id,
          piv_cac_configuration_dn_uuid: cfg.x509_dn_uuid,
          key_id: 'foo',
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
          stub_analytics
          stub_sign_in_before_2fa(user)
          stub_attempts_tracker
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'piv_cac',
            success: true,
            failure_reason: nil,
            reauthentication: false,
          )

          get :show, params: { token: 'good-token' }

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            hash_including(new_device: false),
          )
        end
      end
    end

    context 'when the user presents an invalid piv/cac' do
      subject(:response) { get :show, params: { token: 'bad-token' } }

      before do
        stub_sign_in_before_2fa(user)
      end

      it 'increments second_factor_attempts_count' do
        response

        expect(controller.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the piv/cac entry screen' do
        expect(response).to redirect_to login_two_factor_piv_cac_error_url(error: 'token.invalid')
      end

      it 'resets the piv/cac session information' do
        response

        expect(controller.user_session[:decrypted_x509]).to be_nil
      end

      it 'does not set auth_method and requires 2FA' do
        response

        expect(controller.user_session[:auth_events]).to eq nil
        expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        response
      end
    end

    context 'when the user presents a different piv/cac' do
      subject(:response) { get :show, params: { token: 'good-other-token' } }

      before do
        stub_sign_in_before_2fa(user)
      end

      it 'increments second_factor_attempts_count' do
        response

        expect(controller.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the piv/cac mismatch screen' do
        expect(response).to redirect_to login_two_factor_piv_cac_mismatch_path
      end

      it 'resets the piv/cac session information' do
        response

        expect(controller.user_session[:decrypted_x509]).to be_nil
      end

      context 'when user session context is not authentication' do
        before do
          allow(UserSessionContext).to receive(:authentication_context?).and_return(false)
        end

        it 'redirects to error page with a mismatch error' do
          login_two_factor_piv_cac_error_url(error: 'user.piv_cac_mismatch')
        end
      end

      context 'when user has maximum number of piv/cac associated with their account' do
        before do
          while user.piv_cac_configurations.count < IdentityConfig.store.max_piv_cac_per_account
            create(:piv_cac_configuration, user:)
          end
        end

        it 'redirects to error page with a mismatch error' do
          expect(response).to redirect_to redirect_to login_two_factor_piv_cac_error_url(
            error: 'user.piv_cac_mismatch',
          )
        end
      end
    end

    context 'when the user has reached the max number of piv/cac attempts' do
      render_views

      before do
        user.second_factor_attempts_count =
          IdentityConfig.store.login_otp_confirmation_max_attempts - 1
        user.save
        stub_sign_in_before_2fa(user)

        stub_analytics
        stub_attempts_tracker
      end

      context 'with authentication context' do
        it 'tracks the event' do
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'piv_cac',
            success: false,
            failure_reason: { token: [:invalid] },
            reauthentication: false,
          )
          expect(@attempts_api_tracker).to receive(:mfa_submission_code_rate_limited).with(
            mfa_device_type: 'piv_cac',
          )

          expect(PushNotification::HttpPush).to receive(:deliver)
            .with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

          get :show, params: { token: 'bad-token' }

          expect(@analytics).not_to have_logged_event(:multi_factor_auth_enter_piv_cac)
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: false,
            error_details: { token: { invalid: true } },
            context: 'authentication',
            multi_factor_auth_method: 'piv_cac',
            enabled_mfa_methods_count: 2,
            new_device: true,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication: max attempts reached',
          )
        end
      end

      context 'with confirmation context' do
        before do
          allow(UserSessionContext).to receive(:confirmation_context?).and_return true
        end

        it 'tracks the max attempts event' do
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'piv_cac',
            success: false,
            failure_reason: { token: [:invalid] },
            reauthentication: false,
          )

          expect(@attempts_api_tracker).to receive(:mfa_enroll_code_rate_limited).with(
            mfa_device_type: 'piv_cac',
          )

          expect(PushNotification::HttpPush).to receive(:deliver)
            .with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

          get :show, params: { token: 'bad-token' }

          expect(@analytics).not_to have_logged_event(:multi_factor_auth_enter_piv_cac)
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: false,
            error_details: { token: { invalid: true } },
            context: 'authentication',
            multi_factor_auth_method: 'piv_cac',
            enabled_mfa_methods_count: 2,
            new_device: true,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication: max attempts reached',
          )
        end
      end
    end

    context 'when the user lockout period expires' do
      before(:each) do
        stub_sign_in_before_2fa(user)
      end

      let(:lockout_period) { IdentityConfig.store.lockout_period_in_minutes.minutes }

      let(:user) do
        create(
          :user, :fully_registered, :with_piv_or_cac,
          second_factor_locked_at: Time.zone.now - lockout_period - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an incorrect piv/cac' do
        before(:each) do
          subject.user_session[:decrypted_x509] = '{}'
          get :show, params: { token: 'bad-token' }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end

        it 'resets the x509 session information' do
          expect(subject.user_session[:decrypted_x509]).to be_nil
        end

        it 'sets session value for sign in flow' do
          expect(subject.session[:sign_in_flow]).to eq(:sign_in)
        end
      end

      describe 'when user submits a valid piv/cac' do
        before do
          get :show, params: { token: 'good-token' }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end

        it 'sets session value for sign in flow' do
          expect(subject.session[:sign_in_flow]).to eq(:sign_in)
        end
      end
    end

    context 'when the user does not have a piv/cac associated' do
      context 'and a token is provided' do
        it 'redirects to user_two_factor_authentication_path' do
          stub_sign_in_before_2fa
          get :show, params: { token: '123456' }

          expect(response).to redirect_to user_two_factor_authentication_path
        end
      end

      context 'and no token is provided' do
        it 'redirects to user_two_factor_authentication_path' do
          stub_sign_in_before_2fa
          get :show

          expect(response).to redirect_to user_two_factor_authentication_path
        end
      end
    end
  end
end
