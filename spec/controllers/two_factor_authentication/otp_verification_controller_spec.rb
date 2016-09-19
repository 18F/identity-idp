require 'rails_helper'

describe TwoFactorAuthentication::OtpVerificationController, devise: true do
  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
      end

      context 'when FeatureManagement.prefill_otp_codes? is true' do
        it 'sets @code_value to correct OTP value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
          get :show, delivery_method: 'sms'

          expect(assigns(:code_value)).to eq(subject.current_user.direct_otp)
        end
      end

      context 'when FeatureManagement.prefill_otp_codes? is false' do
        it 'does not set @code_value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)
          get :show, delivery_method: 'sms'

          expect(assigns(:code_value)).to be_nil
        end
      end
    end
  end

  describe '#create' do
    context 'when the user enters an invalid OTP' do
      before do
        sign_in_before_2fa

        stub_analytics
        expect(@analytics).to receive(:track_event).with('User entered invalid 2FA code')

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        expect(subject.current_user).to receive(:authenticate_direct_otp).and_return(false)
        post :create, code: '12345', delivery_method: 'sms'
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the OTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
      end
    end

    context 'when the user has reached the max number of OTP attempts' do
      it 'tracks the event' do
        sign_in_before_2fa

        stub_analytics

        expect(@analytics).to receive(:track_event).exactly(3).times.
          with('User entered invalid 2FA code')
        expect(@analytics).to receive(:track_event).with('User reached max 2FA attempts')

        3.times { post :create, code: '12345', delivery_method: 'sms' }
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa
        expect(subject.current_user).to receive(:authenticate_direct_otp).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'redirects to the profile' do
        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'

        expect(response).to redirect_to profile_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('User 2FA successful')
        expect(@analytics).to receive(:track_event).with('Authentication Successful')

        post :create, code: subject.current_user.reload.direct_otp, delivery_method: 'sms'
      end
    end

    context 'when user has not changed their number' do
      it 'does not perform SmsSenderNumberChangeJob' do
        user = create(:user, :signed_up)
        sign_in user

        expect(SmsSenderNumberChangeJob).to_not receive(:perform_later).with(user)

        post :create, code: user.direct_otp, delivery_method: 'sms'
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an invalid OTP' do
        before do
          post :create, code: '12345', delivery_method: 'sms'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid OTP' do
        before do
          post :create, code: subject.current_user.direct_otp, delivery_method: 'sms'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end
  end
end
