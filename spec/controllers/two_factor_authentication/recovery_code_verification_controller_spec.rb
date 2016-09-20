require 'rails_helper'

describe TwoFactorAuthentication::RecoveryCodeVerificationController, devise: true do
  describe '#create' do
    context 'when the user enters a valid recovery code' do
      before do
        stub_sign_in_before_2fa(User.new(recovery_code: 'foo'))
        form = instance_double(RecoveryCodeForm)
        allow(RecoveryCodeForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(success?: true)
      end

      it 'redirects to the profile' do
        post :create, code: 'foo'

        expect(response).to redirect_to profile_path
      end

      it 'calls handle_valid_otp' do
        expect(subject).to receive(:handle_valid_otp).and_call_original

        post :create, code: 'foo'
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        analytics_hash = { success?: true }

        expect(@analytics).to receive(:track_event).
          with(:recovery_code_authentication, analytics_hash).ordered
        expect(@analytics).to receive(:track_event).with('User 2FA successful').ordered
        expect(@analytics).to receive(:track_event).with('Authentication Successful').ordered

        post :create, code: 'foo'
      end
    end

    context 'when the user enters an invalid recovery code' do
      before do
        stub_sign_in_before_2fa
        form = instance_double(RecoveryCodeForm)
        allow(RecoveryCodeForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(success?: false)
      end

      it 'calls handle_invalid_otp' do
        expect(subject).to receive(:handle_invalid_otp).and_call_original

        post :create, code: 'foo'
      end

      it 're-renders the recovery code entry screen' do
        post :create, code: 'foo'

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_recovery_code')
      end
    end
  end
end
