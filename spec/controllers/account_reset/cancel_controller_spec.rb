require 'rails_helper'

describe AccountReset::CancelController do
  include AccountResetHelper

  let(:user) { create(:user, :signed_up) }

  describe '#create' do
    it 'logs a good token to the analytics' do
      token = create_account_reset_request_for(user)
      session[:cancel_token] = token

      stub_analytics
      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        message_id: 'fake-message-id',
        request_id: 'fake-message-request-id',
      }

      expect(@analytics).to receive(:track_event).with('Account Reset: cancel', analytics_hash)

      post :create
    end

    it 'logs a bad token to the analytics' do
      stub_analytics
      analytics_hash = {
        success: false,
        errors: { token: [t('errors.account_reset.cancel_token_invalid', app_name: APP_NAME)] },
        error_details: {
          token: { cancel_token_invalid: true },
        },
        user_id: 'anonymous-uuid',
      }

      expect(@analytics).to receive(:track_event).with('Account Reset: cancel', analytics_hash)
      session[:cancel_token] = 'FOO'

      post :create
    end

    it 'logs a missing token to the analytics' do
      stub_analytics
      analytics_hash = {
        success: false,
        errors: { token: [t('errors.account_reset.cancel_token_missing', app_name: APP_NAME)] },
        error_details: { token: { blank: true } },
        user_id: 'anonymous-uuid',
      }

      expect(@analytics).to receive(:track_event).with('Account Reset: cancel', analytics_hash)

      post :create
    end

    it 'redirects to the root without a flash message when the token is missing or invalid' do
      post :create
      expect(response).to redirect_to root_url
    end

    it 'redirects to the root with a flash message when the token is valid' do
      token = create_account_reset_request_for(user)
      session[:cancel_token] = token

      post :create

      expect(flash[:success]).
        to eq t('two_factor_authentication.account_reset.successful_cancel', app_name: APP_NAME)
      expect(response).to redirect_to root_url
    end

    it 'signs the user out if signed in and if the token is valid' do
      stub_sign_in(user)

      token = create_account_reset_request_for(user)
      session[:cancel_token] = token

      expect(controller).to receive(:sign_out)

      post :create
    end
  end

  describe '#show' do
    it 'redirects to root if the token does not match one in the DB' do
      stub_analytics
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.cancel_token_invalid', app_name: APP_NAME)] },
        error_details: {
          token: { cancel_token_invalid: true },
        },
      }
      expect(@analytics).to receive(:track_event).
        with('Account Reset: cancel token validation', properties)

      get :show, params: { token: 'FOO' }

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq t('errors.account_reset.cancel_token_invalid', app_name: APP_NAME)
    end

    it 'renders the show view if the token is missing' do
      get :show

      expect(response).to render_template(:show)
    end
  end
end
