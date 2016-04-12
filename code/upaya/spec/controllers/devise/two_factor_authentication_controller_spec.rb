require 'rails_helper'

describe Devise::TwoFactorAuthenticationController, devise: true do
  describe 'update' do
    let(:user) { create(:user, :tfa_confirmed) }

    context 'when resource is no longer OTP locked out' do
      before do
        sign_in user
        user.send_two_factor_authentication_code
        user.update(
          second_factor_locked_at: Time.zone.now - (Devise.allowed_otp_drift_seconds + 1).seconds)
        user.update(second_factor_attempts_count: 3)
      end

      it 'resets attempts count when user submits bad code' do
        patch :update, code: '12345'

        expect(user.reload.second_factor_attempts_count).to eq 1
      end

      it 'resets second_factor_locked_at when user submits correct code' do
        patch :update, code: user.otp_code

        expect(user.reload.second_factor_locked_at).to be_nil
      end
    end
  end
end
