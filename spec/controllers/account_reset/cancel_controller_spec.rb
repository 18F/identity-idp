require 'rails_helper'

describe AccountReset::CancelController do
  include AccountResetHelper

  let(:user) { create(:user, :signed_up) }
  before do
    TwilioService::Utils.telephony_service = FakeSms
  end

  describe '#create' do
    it 'logs a good token to the analytics' do
      token = create_account_reset_request_for(user)

      stub_analytics
      analytics_hash = {
        success: true,
        errors: {},
        event: 'cancel',
        user_id: user.uuid,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, analytics_hash)

      post :create, params: { token: token }
    end

    it 'logs a bad token to the analytics' do
      stub_analytics
      analytics_hash = {
        success: false,
        errors: { token: [t('errors.account_reset.cancel_token_invalid')] },
        event: 'cancel',
        user_id: 'anonymous-uuid',
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, analytics_hash)

      post :create, params: { token: 'FOO' }
    end

    it 'logs a missing token to the analytics' do
      stub_analytics
      analytics_hash = {
        success: false,
        errors: { token: [t('errors.account_reset.cancel_token_missing')] },
        event: 'cancel',
        user_id: 'anonymous-uuid',
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, analytics_hash)

      post :create
    end

    it 'redirects to the root without a flash message when the token is missing or invalid' do
      post :create
      expect(response).to redirect_to root_url
    end

    it 'redirects to the root with a flash message when the token is valid' do
      token = create_account_reset_request_for(user)

      post :create, params: { token: token }

      expect(flash[:success]).
        to eq t('two_factor_authentication.account_reset.successful_cancel')
      expect(response).to redirect_to root_url
    end

    it 'signs the user out if signed in and if the token is valid' do
      stub_sign_in(user)

      token = create_account_reset_request_for(user)

      expect(controller).to receive(:sign_out)

      post :create, params: { token: token }
    end
  end
end
