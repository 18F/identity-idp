require 'rails_helper'

describe Users::PhoneSetupController do
  describe 'GET index' do
    context 'when signed out' do
      it 'redirects to sign in page' do
        expect(PhoneSetupPresenter).to_not receive(:new)

        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when signed in' do
      it 'renders the index view' do
        stub_analytics
        user = build(:user, otp_delivery_preference: 'voice')
        stub_sign_in_before_2fa(user)

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
        expect(PhoneSetupPresenter).to receive(:new).with(user.otp_delivery_preference)
        expect(UserPhoneForm).to receive(:new).with(user, nil)

        get :index

        expect(response).to render_template(:index)
      end
    end
  end

  describe 'PATCH create' do
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

      patch :create, params: {
        user_phone_form: {
          phone: '703-555-010',
          international_code: 'US',
        },
      }

      expect(response).to render_template(:index)
    end

    context 'with voice' do
      let(:user) { create(:user, otp_delivery_preference: 'voice') }

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
          :create,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               international_code: 'US' },
          },
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
          ),
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
          :create,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               international_code: 'US' },
          },
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
          ),
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
          :create,
          params: {
            user_phone_form: { phone: '703-555-0100',
                               international_code: 'US' },
          },
        )

        expect(response).to redirect_to(
          otp_send_path(
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
          ),
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
        :authorize_user,
      )
    end
  end

  describe '#authorize_user' do
    context 'when the user is fully authenticated and phone enabled' do
      it 'redirects to account url' do
        user = build_stubbed(:user, :with_phone)
        stub_sign_in(user)

        get :index

        expect(response).to redirect_to(account_url)
      end
    end

    context 'when the user is two_factor_enabled but not fully authenticated' do
      it 'prompts to enter OTP' do
        user = build(:user, :signed_up)
        stub_sign_in_before_2fa(user)

        get :index

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end
  end
end
