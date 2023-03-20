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

    context 'with a new account' do
      let(:mfa_selections) { ['webauthn'] }
      let(:unconfirmed_phone) { '+1 (202) 555-5555' }
      let(:context) { true }

      allow_any_instance_of(UserSessionContext).to receive(:confirmation_context).and_return(context)

      before do
        user = build(:user)
        stub_sign_in(user)
        controller.user_session[:mfa_selections] = mfa_selections
        controller.user_session[:unconfirmed_phone] = unconfirmed_phone
      end

      it 'assigns authentication_options_path to authentication methods setup screen' do
        get :show

        expect(assigns(:authentication_options_path)).to eq(authentication_methods_setup_url)
      end

      xit 'assigns use_another_phone_path to the phone setup path' do
        get :show

        expect(assigns(:use_another_phone_path)).to eq(nil)
      end
    end

    context 'with an existing account signing in' do
      let(:mfa_selections) { ['webauthn, phone'] }

      before do
        user = create(:user, :with_phone)
        stub_sign_in_before_2fa(user)
        controller.user_session[:mfa_selections] = mfa_selections
      end

      it 'assigns authentication_options_path to the login two factor options url' do
        get :show

        expect(assigns(:authentication_options_path)).to eq(login_two_factor_options_url)
      end

      it 'assigns use_another_phone_path to nil' do
        get :show

        expect(assigns(:use_another_phone_path)).to be_nil
      end
    end

    context 'with an existing account adding a phone' do
    end
  end
end
