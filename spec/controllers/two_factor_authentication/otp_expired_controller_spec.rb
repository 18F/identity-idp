require 'rails_helper'

describe TwoFactorAuthentication::OtpExpiredController do
  let(:delivery_preference) { 'voice' }
  before do
    allow(IdentityConfig.store).to receive(:allow_otp_countdown_expired_redirect).
      and_return(true)
  end
  describe '#show' do
    it 'global otp_delivery_preference variable properly defined' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           with: { phone: '+1 (703) 555-0000' }
      )
      user.create_direct_otp
      stub_sign_in_before_2fa(user)

      get :show

      expect(assigns(:otp_delivery_preference)).to eq('voice')
    end

    it 'renders template' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           with: { phone: '+1 (703) 555-0000' }
      )
      user.create_direct_otp
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to render_template(:show)
    end

    it 'tracks user otp expired navigation analytics' do
      user = create(
        :user, :signed_up, otp_delivery_preference: delivery_preference,
                           with: { phone: '+1 (703) 555-0000' }
      )
      freeze_time do
        user.create_direct_otp
        stub_analytics
        analytics_hash = {
          otp_sent_at: user.redis_direct_otp_sent_at,
          otp_expiration: user.redis_direct_otp_expires_at,
        }
        stub_sign_in_before_2fa(user)

        expect(@analytics).to receive(:track_event).
          with('OTP Expired Page Visited', analytics_hash)
        get :show
      end
    end

    context 'user is signed out' do
      it 'does not render template' do
        allow(controller).to receive(:user_signed_in?).and_return(false)

        get :show

        expect(response).to_not render_template(:show)
      end
    end

    context 'otp expired redirect feature is turned off' do
    end
  end
end
