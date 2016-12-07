require 'rails_helper'

describe TwoFactorAuthentication::TotpVerificationController, devise: true do
  describe '#create' do
    context 'when the user enters a valid TOTP' do
      before do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        subject.current_user.otp_secret_key = @secret
      end

      it 'redirects to the profile' do
        expect(subject.current_user).to receive(:authenticate_totp).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        post :create, code: generate_totp_code(@secret)

        expect(response).to redirect_to profile_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        post :create, code: generate_totp_code(@secret)

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH, success: true, method: 'totp')

        post :create, code: generate_totp_code(@secret)
      end
    end

    context 'when the user enters an invalid TOTP' do
      before do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        subject.current_user.otp_secret_key = @secret
        post :create, code: 'abc'
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 're-renders the TOTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_otp')
      end
    end

    context 'when the user has reached the max number of TOTP attempts' do
      it 'tracks the event' do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        subject.current_user.otp_secret_key = @secret

        stub_analytics

        expect(@analytics).to receive(:track_event).exactly(3).times.
          with(Analytics::MULTI_FACTOR_AUTH, success: false, method: 'totp')
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

        3.times { post :create, code: '12345' }
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        subject.current_user.otp_secret_key = @secret
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an invalid TOTP' do
        before do
          post :create, code: '12345'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid TOTP' do
        before do
          post :create, code: generate_totp_code(@secret)
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
