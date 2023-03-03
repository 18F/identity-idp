require 'rails_helper'

describe TwoFactorAuthentication::OtpExpiredController do
  let(:direct_otp_sent_at) { Time.zone.now }
  let(:delivery_preference) { 'voice' }
  before do
    allow(IdentityConfig.store).to receive(:allow_otp_countdown_expired_redirect).
      and_return(true)
  end
  describe '#show' do
    it 'global otp_delivery_preference variable properly defined' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           direct_otp_sent_at: direct_otp_sent_at,
                           with: { phone: '+1 (703) 555-0000' }
      )
      stub_sign_in_before_2fa(user)

      get :show

      expect(assigns(:otp_delivery_preference)).to eq('voice')
    end

    it 'renders template' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           direct_otp_sent_at: direct_otp_sent_at,
                           with: { phone: '+1 (703) 555-0000' }
      )
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to render_template(:show)
    end

    it 'tracks user otp expired navigation analytics' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           direct_otp_sent_at: direct_otp_sent_at,
                           with: { phone: '+1 (703) 555-0000' }
      )
      stub_analytics
      otp_expiration = direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
      analytics_hash = { otp_sent_at: direct_otp_sent_at, otp_expiration: otp_expiration }
      stub_sign_in_before_2fa(user)

      expect(@analytics).to receive(:track_event).
        with('OTP Expired Page Visited', analytics_hash)
      get :show
    end

    context 'user is signed out' do
      it 'does not render template' do
        allow(controller).to receive(:user_signed_in?).and_return(false)

        get :show

        expect(response).to_not render_template(:show)
      end
    end

    context 'otp expired redirect feature is turned off' do
      it 'does not redirect' do
        allow(IdentityConfig.store).to receive(:allow_otp_countdown_expired_redirect).and_return(false)

        get :show
  
        expect(response).to_not render_template(:show)
      end
    end
  end
end
