require 'rails_helper'

describe TwoFactorAuthentication::OtpExpiredController do
  describe '#show' do
    context 'renders' do
      it 'receives the expected value' do
        user = build(:user, otp_delivery_preference: 'voice')

        allow(controller).to receive(:otp_expired?).and_return(true)

        stub_sign_in_before_2fa(user)

        get :show

        expect(assigns(:otp_delivery_preference)).to eq('voice')
      end

      it 'once OTP expires' do
        user = build(:user, otp_delivery_preference: 'voice', direct_otp_sent_at: Time.zone.now)

        allow(controller).to receive(:otp_expired?).and_return(true)
        stub_sign_in_before_2fa(user)

        get :show

        expect(response).to render_template(:show)
      end
    end

    context 'does not render' do
      it 'when user is signed out' do
        allow(controller).to receive(:user_signed_in?).and_return(false)

        get :show

        expect(response).to_not render_template(:show)
      end

      it 'when otp is still valid' do
        get :show

        expect(response).to_not render_template(:show)
      end
    end
  end
end
