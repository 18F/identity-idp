require 'rails_helper'

describe Devise::TwoFactorAuthenticationSetupController, devise: true do
  describe 'GET index' do
    context 'when signed out' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  describe 'PATCH set' do
    let(:user) { create(:user) }

    it 'prompts to confirm the number' do
      sign_in(user)

      stub_analytics
      expect(@analytics).to receive(:track_event).with('2FA setup: valid phone number')

      patch(
        :set,
        two_factor_setup_form: { phone: '703-555-0100',
                                 phone_sms_enabled: '1' }
      )

      expect(response).to redirect_to(phone_confirmation_send_path)
    end

    describe 'delivery preference' do
      it 'sets SMS enabled to true' do
        sign_in(user)

        patch(
          :set,
          two_factor_setup_form: { phone: '703-555-0100',
                                   phone_sms_enabled: '1' }
        )

        expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to eq(true)
      end

      it 'sets SMS enabled to false' do
        sign_in(user)

        patch(
          :set,
          two_factor_setup_form: { phone: '703-555-0100',
                                   phone_sms_enabled: '0' }
        )

        expect(subject.user_session[:unconfirmed_phone_sms_enabled]).to eq(false)
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_scope!,
        :authorize_otp_setup
      )
    end
  end

  describe '#authorize_otp_setup' do
    context 'when the user is fully authenticated' do
      it 'redirects to root url' do
        user = create(:user, :signed_up)
        sign_in(user)

        get :index

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when the user is two_factor_enabled but not fully authenticated' do
      it 'prompts to enter OTP' do
        sign_in_before_2fa

        get :index

        expect(response).to redirect_to(user_two_factor_authentication_path)
      end
    end
  end
end
