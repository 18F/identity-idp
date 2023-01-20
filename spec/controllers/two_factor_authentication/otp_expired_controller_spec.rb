require 'rails_helper'

describe TwoFactorAuthentication::OtpExpiredController do
  describe '#show' do
    it 'renders the page on sign in' do
      sign_in_before_2fa

      get :show

      expect(response).to render_template(:show)
    end

    it 'renders the page when adding a new one time code method' do
      user = build(:user, otp_delivery_preference: 'voice')

      stub_sign_in_before_2fa(user)
      get :show

      expect(response).to render_template(:show)
    end
  end
end
