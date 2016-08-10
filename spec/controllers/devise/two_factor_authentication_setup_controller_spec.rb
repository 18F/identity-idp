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

    it 'tracks an event when the number is invalid' do
      allow(subject).to receive(:authenticate_scope!).and_return(true)
      allow(subject).to receive(:authorize_otp_setup).and_return(true)

      stub_analytics
      expect(@analytics).to receive(:track_event).with('2FA setup: invalid phone number')

      patch :set, two_factor_setup_form: { phone: '703-555-010' }

      expect(response).to render_template(:index)
    end

    context 'with voice' do
      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics
        expect(@analytics).to receive(:track_event).with('2FA setup: valid phone number')

        patch(
          :set,
          two_factor_setup_form: { phone: '703-555-0100',
                                   voice: 'Confirm with voice call' }
        )

        expect(response).to redirect_to(
          phone_confirmation_send_path(delivery_method: :voice)
        )
      end
    end

    context 'with SMS' do
      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics
        expect(@analytics).to receive(:track_event).with('2FA setup: valid phone number')

        patch(
          :set,
          two_factor_setup_form: { phone: '703-555-0100',
                                   sms: 'Confirm with text message' }
        )

        expect(response).to redirect_to(
          phone_confirmation_send_path(delivery_method: :sms)
        )
      end
    end

    context 'without selection' do
      it 'prompts to confirm via SMS by default' do
        sign_in(user)

        stub_analytics
        expect(@analytics).to receive(:track_event).with('2FA setup: valid phone number')

        patch(
          :set,
          two_factor_setup_form: { phone: '703-555-0100' }
        )

        expect(response).to redirect_to(
          phone_confirmation_send_path(delivery_method: :sms)
        )
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
