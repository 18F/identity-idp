require 'rails_helper'

describe Devise::TwoFactorAuthenticationController, devise: true do
  describe 'update' do
    let(:user) { create(:user, :signed_up) }

    context 'when user only has email 2FA' do
      it 'does not perform SmsSenderNumberChangeJob' do
        sign_in user
        user.send_two_factor_authentication_code

        expect(SmsSenderNumberChangeJob).
          to_not receive(:perform_later).with(user)

        patch :update, code: user.otp_code
      end
    end

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

  describe 'show' do
    context 'when resource is not fully authenticated yet' do
      it 'renders the show view' do
        sign_in_before_2fa
        get :show

        expect(response).to_not be_redirect
        expect(response).to render_template(:show)
      end
    end

    context 'when resource is fully authenticated and does not have unconfirmed mobile' do
      it 'redirects to the dashboard' do
        user = create(:user, :signed_up)
        sign_in user
        get :show

        expect(response).to redirect_to dashboard_index_path
      end
    end

    context 'when resource is fully authenticated but has unconfirmed mobile' do
      it 'renders the show view' do
        user = create(:user, :signed_up, unconfirmed_mobile: '202-555-1212')
        sign_in user
        get :show

        expect(response).to render_template(:show)
      end
    end
  end
end
