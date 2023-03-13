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
        allow(IdentityConfig.store).to receive(:allow_otp_countdown_expired_redirect).
          and_return(false)

        get :show

        expect(response).to_not render_template(:show)
      end
    end

    context 'authentication options redirect' do
      let(:mfa_selections) { nil }

      it 'sets authentication options path correctly' do
        user = create(:user, :signed_up)
        stub_sign_in_before_2fa(user)

        get :show

        expect(assigns(:authentication_options_path)).to eq(login_two_factor_options_url)
      end
    end

    context 'unconfirmed phone option' do
      before do
        @user = create(:user)
        @show_use_another_phone_option = '+1 (202) 555-1213'
      end

      it 'assigns the value correctly' do
        stub_sign_in_before_2fa(@user)
        subject.user_session[:show_use_another_phone_option] = @show_use_another_phone_option

        get :show
        expect(assigns(:show_use_another_phone_option)).to eq(false)
      end
    end
  end
end
