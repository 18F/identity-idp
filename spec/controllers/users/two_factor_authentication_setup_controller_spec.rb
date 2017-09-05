require 'rails_helper'

describe Users::TwoFactorAuthenticationSetupController do
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
      sign_in(user)

      stub_analytics
      result = {
        success: false,
        errors: { phone: [t('errors.messages.improbable_phone')] },
        otp_delivery_preference: 'sms',
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result)

      patch :set, params: {
        user_phone_form: {
          phone: '703-555-010',
          otp_delivery_preference: :sms,
          international_code: 'US',
        },
      }

      expect(response).to render_template(:index)
    end

    context 'with voice' do
      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics
        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'voice',
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result)

        patch(
          :set,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               otp_delivery_preference: 'voice',
                               international_code: 'US' },
          }
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'voice' }
          )
        )

        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'with SMS' do
      it 'prompts to confirm the number' do
        sign_in(user)

        stub_analytics

        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result)

        patch(
          :set,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               otp_delivery_preference: :sms,
                               international_code: 'US' },
          }
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' }
          )
        )

        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end

    context 'without selection' do
      it 'prompts to confirm via SMS by default' do
        sign_in(user)

        stub_analytics
        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result)

        patch(
          :set,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               otp_delivery_preference: :sms,
                               international_code: 'US' },
          }
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' }
          )
        )

        expect(subject.user_session[:context]).to eq 'confirmation'
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user,
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
