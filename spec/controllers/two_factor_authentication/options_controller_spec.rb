require 'rails_helper'

describe TwoFactorAuthentication::OptionsController do
  describe '#index' do
    it 'renders the page' do
      sign_in_before_2fa

      get :index

      expect(response).to render_template(:index)
    end

    it 'logs an analytics event' do
      sign_in_before_2fa
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: option list visited')

      get :index
    end
  end

  describe '#create' do
    before { sign_in_before_2fa }

    it 'redirects to login_two_factor_url if user selects sms' do
      post :create, params: { two_factor_options_form: { selection: 'sms' } }

      expect(response).to redirect_to otp_send_url( \
        otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
      )
    end

    it 'redirects to login_two_factor_url if user selects voice' do
      post :create, params: { two_factor_options_form: { selection: 'voice' } }

      expect(response).to redirect_to otp_send_url( \
        otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
      )
    end

    it 'redirects to login_two_factor_piv_cac_url if user selects piv_cac' do
      post :create, params: { two_factor_options_form: { selection: 'piv_cac' } }

      expect(response).to redirect_to login_two_factor_piv_cac_url
    end

    it 'redirects to login_two_factor_authenticator_url if user selects auth_app' do
      post :create, params: { two_factor_options_form: { selection: 'auth_app' } }

      expect(response).to redirect_to login_two_factor_authenticator_url
    end

    it 'redirects to login_two_factor_webauthn_url if user selects webauthn' do
      post :create, params: { two_factor_options_form: { selection: 'webauthn' } }

      expect(response).to redirect_to login_two_factor_webauthn_url
    end

    it 'redirects to login_two_factor_webauthn_url with param if user selects platform auth' do
      post :create, params: { two_factor_options_form: { selection: 'webauthn_platform' } }

      expect(response).to redirect_to login_two_factor_webauthn_url(platform: true)
    end

    it 'sets phone_id in session when selecting a phone option' do
      post :create, params: { two_factor_options_form: { selection: 'sms_0' } }

      expect(controller.user_session[:phone_id]).to eq('0')
    end

    it 'rerenders the page with errors on failure' do
      post :create, params: { two_factor_options_form: { selection: 'foo' } }

      expect(response).to render_template(:index)
    end

    it 'tracks analytics event' do
      stub_sign_in_before_2fa
      stub_analytics

      result = {
        selection: 'sms',
        success: true,
        errors: {},
      }

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: option list', result)

      post :create, params: { two_factor_options_form: { selection: 'sms' } }
    end
  end
end
