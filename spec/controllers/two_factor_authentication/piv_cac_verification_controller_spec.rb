require 'rails_helper'

describe TwoFactorAuthentication::PivCacVerificationController do
  let(:user) do
    create(
      :user, :signed_up, :with_piv_or_cac,
      with: { phone: '+1 (703) 555-0000' }
    )
  end

  let(:nonce) { 'once' }

  let(:x509_subject) { 'o=US, ou=DoD, cn=John.Doe.1234' }
  let(:x509_issuer) do
    '/C=US/O=Entrust/OU=Certification Authorities/OU=Entrust Managed Services SSP CA'
  end

  before(:each) do
    session_info = { piv_cac_nonce: nonce }
    allow(subject).to receive(:user_session).and_return(session_info)
    allow(PivCacService).to receive(:decode_token).with('good-token').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid,
      'subject' => x509_subject,
      'issuer' => x509_issuer,
      'nonce' => nonce,
    )
    allow(PivCacService).to receive(:decode_token).with('good-other-token').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid + 'X',
      'subject' => x509_subject + 'X',
      'issuer' => x509_issuer,
      'nonce' => nonce,
    )
    allow(PivCacService).to receive(:decode_token).with('bad-token').and_return(
      'uuid' => 'bad-uuid',
      'subject' => 'bad-dn',
      'issuer' => x509_issuer,
      'nonce' => nonce,
    )
    allow(PivCacService).to receive(:decode_token).with('bad-nonce').and_return(
      'uuid' => user.piv_cac_configurations.first.x509_dn_uuid,
      'subject' => x509_subject,
      'issuer' => x509_issuer,
      'nonce' => 'bad-' + nonce,
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
    end

    context 'when the user presents a valid PIV/CAC' do
      before(:each) do
        stub_sign_in_before_2fa(user)
      end

      it 'redirects to the profile' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        get :show, params: { token: 'good-token' }

        expect(response).to redirect_to account_path
        expect(subject.user_session[:decrypted_x509]).to eq(
          {
            'subject' => x509_subject,
            'issuer' => x509_issuer,
            'presented' => true,
          }.to_json,
        )
      end

      it 'resets the second_factor_attempts_count' do
        UpdateUser.new(
          user: subject.current_user,
          attributes: { second_factor_attempts_count: 1 },
        ).call

        get :show, params: { token: 'good-token' }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        stub_attempts_tracker

        attributes = {
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          piv_cac_configuration_id: nil,
        }

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: enter PIV CAC visited', attributes)

        submit_attributes = {
          success: true,
          errors: {},
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          piv_cac_configuration_id: nil,
        }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(submit_attributes)

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :mfa_login_piv_cac,
          success: true,
          subject_dn: x509_subject,
          failure_reason: nil,
        )

        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        get :show, params: { token: 'good-token' }
      end
    end

    context 'when the user presents an invalid piv/cac' do
      before do
        stub_sign_in_before_2fa(user)

        get :show, params: { token: 'bad-token' }
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the piv/cac entry screen' do
        expect(response).to redirect_to login_two_factor_piv_cac_path
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_piv_cac')
      end

      it 'resets the piv/cac session information' do
        expect(subject.user_session[:decrypted_x509]).to be_nil
      end
    end

    context 'when the user presents a different piv/cac' do
      before do
        stub_sign_in_before_2fa(user)

        get :show, params: { token: 'good-other-token' }
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the piv/cac entry screen' do
        expect(response).to redirect_to login_two_factor_piv_cac_path
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_piv_cac')
      end

      it 'resets the piv/cac session information' do
        expect(subject.user_session[:decrypted_x509]).to be_nil
      end
    end

    context 'when the user has reached the max number of piv/cac attempts' do
      render_views

      it 'tracks the event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        stub_sign_in_before_2fa(user)

        stub_analytics
        stub_attempts_tracker

        attributes = {
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          piv_cac_configuration_id: nil,
        }

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: enter PIV CAC visited', attributes)

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_rate_limited).
          with(mfa_device_type: 'piv_cac')

        submit_attributes = {
          success: false,
          errors: { type: 'user.piv_cac_mismatch' },
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
          key_id: nil,
          piv_cac_configuration_id: nil,
        }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(submit_attributes)

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :mfa_login_piv_cac,
          success: false,
          subject_dn: 'bad-dn',
          failure_reason: { type: 'user.piv_cac_mismatch' },
        )

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        get :show, params: { token: 'bad-token' }
      end
    end

    context 'when the user lockout period expires' do
      before(:each) do
        stub_sign_in_before_2fa(user)
      end

      let(:lockout_period) { IdentityConfig.store.lockout_period_in_minutes.minutes }

      let(:user) do
        create(
          :user, :signed_up, :with_piv_or_cac,
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
