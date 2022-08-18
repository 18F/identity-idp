require 'rails_helper'

describe TwoFactorAuthentication::BackupCodeVerificationController do
  let(:backup_code) { { backup_code: 'foo' } }
  let(:payload) { { backup_code_verification_form: backup_code } }

  describe '#show' do
    it 'tracks the page visit' do
      stub_sign_in_before_2fa
      stub_analytics
      analytics_hash = { context: 'authentication' }

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: enter backup code visited', analytics_hash)

      get :show
    end
  end

  describe '#create' do
    context 'when the user enters a valid backup code' do
      it 'tracks the valid authentication event' do
        sign_in_before_2fa

        form = instance_double(BackupCodeVerificationForm)
        response = FormResponse.new(
          success: true, errors: {}, extra: { multi_factor_auth_method: 'backup_code' },
        )
        allow(BackupCodeVerificationForm).to receive(:new).
          with(subject.current_user).and_return(form)
        allow(form).to receive(:submit).and_return(response)

        stub_analytics
        stub_attempts_tracker
        analytics_hash = { success: true, errors: {}, multi_factor_auth_method: 'backup_code' }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(analytics_hash)

        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_verify_backup_code, success: true)

        post :create, params: payload
      end

      it 'tracks the valid authentication event when there are exisitng codes' do
        user = build(:user, :with_phone, with: { phone: '+1 (703) 555-1212' })
        BackupCodeGenerator.new(user).create
        stub_sign_in_before_2fa(user)

        form = instance_double(BackupCodeVerificationForm)
        response = FormResponse.new(
          success: true, errors: {}, extra: { multi_factor_auth_method: 'backup_code' },
        )
        allow(BackupCodeVerificationForm).to receive(:new).
          with(subject.current_user).and_return(form)
        allow(form).to receive(:submit).and_return(response)

        stub_analytics
        stub_attempts_tracker
        analytics_hash = { success: true, errors: {}, multi_factor_auth_method: 'backup_code' }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(analytics_hash)

        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_verify_backup_code, success: true)

        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        post :create, params: payload
      end
    end

    context 'when the backup code field is empty' do
      let(:backup_code) { { backup_code: '' } }
      let(:payload) { { backup_code_verification_form: backup_code } }

      before do
        stub_sign_in_before_2fa(build(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))
        form = instance_double(BackupCodeVerificationForm)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'backup_code' },
        )
        allow(BackupCodeVerificationForm).to receive(:new).
          with(subject.current_user).and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'renders the show page' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_verify_backup_code, success: false)
        post :create, params: payload
        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_backup_code')
      end
    end

    context 'when the user enters an invalid backup code' do
      render_views
      before do
        user = build(:user, :with_phone, with: { phone: '+1 (703) 555-1212' })
        stub_sign_in_before_2fa(user)
        form = BackupCodeVerificationForm.new(user)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'backup_code' },
        )
        allow(BackupCodeVerificationForm).to receive(:new).
          with(subject.current_user).and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 're-renders the backup code entry screen' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_verify_backup_code, success: false)
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_backup_code')
      end

      it 'tracks the max attempts event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        properties = {
          success: false,
          errors: {},
          multi_factor_auth_method: 'backup_code',
        }

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)

        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_verify_backup_code, success: false)

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        post :create, params: payload
      end
    end
  end
end
