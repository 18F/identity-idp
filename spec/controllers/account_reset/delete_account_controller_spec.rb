require 'rails_helper'

RSpec.describe AccountReset::DeleteAccountController do
  include AccountResetHelper

  let(:invalid_token_message) do
    t('errors.account_reset.granted_token_invalid', app_name: APP_NAME)
  end
  let(:invalid_token_error) { { token: [invalid_token_message] } }

  before { stub_analytics }
  describe '#delete' do
    it 'logs a good token to the analytics' do
      user = create(:user, :fully_registered, :with_backup_code, confirmed_at: Time.zone.now.round)
      create(:phone_configuration, user: user, phone: Faker::PhoneNumber.cell_phone)
      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)

      session[:granted_token] = AccountResetRequest.first.granted_token
      properties = {
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: { backup_codes: 10, webauthn: 2, phone: 2 },
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      }
      expect(@analytics).
        to receive(:track_event).with('Account Reset: delete', properties)

      delete :delete

      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'redirects to root if the token does not match one in the DB' do
      session[:granted_token] = 'foo'
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: invalid_token_error,
        error_details: invalid_token_error,
        mfa_method_counts: {},
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
        account_confirmed_at: kind_of(Time),
      }
      expect(@analytics).to receive(:track_event).with('Account Reset: delete', properties)

      delete :delete

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(invalid_token_message)
    end

    it 'displays a flash and redirects to root if the token is missing' do
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_missing', app_name: APP_NAME)] },
        error_details: { token: [:blank] },
        mfa_method_counts: {},
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
        account_confirmed_at: kind_of(Time),
      }
      expect(@analytics).to receive(:track_event).with('Account Reset: delete', properties)

      delete :delete

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq t(
        'errors.account_reset.granted_token_missing',
        app_name: APP_NAME,
      )
    end

    it 'displays a flash and redirects to root if the token is expired' do
      user = create(:user)
      create_account_reset_request_for(user)
      grant_request(user)

      properties = {
        user_id: user.uuid,
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)] },
        error_details: {
          token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)],
        },
        mfa_method_counts: {},
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 2,
        account_confirmed_at: kind_of(Time),
      }
      expect(@analytics).to receive(:track_event).with('Account Reset: delete', properties)

      travel_to(Time.zone.now + 2.days) do
        session[:granted_token] = AccountResetRequest.first.granted_token
        delete :delete
      end

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(
        t('errors.account_reset.granted_token_expired', app_name: APP_NAME),
      )
    end
  end

  describe '#show' do
    it 'redirects to root if the token does not match one in the DB' do
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: invalid_token_error,
        error_details: invalid_token_error,
      }
      expect(@analytics).to receive(:track_event).
        with('Account Reset: granted token validation', properties)

      get :show, params: { token: 'FOO' }

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(invalid_token_message)
    end

    it 'displays a flash and redirects to root if the token is expired' do
      user = create(:user)
      create_account_reset_request_for(user)
      grant_request(user)

      properties = {
        user_id: user.uuid,
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)] },
        error_details: {
          token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)],
        },
      }
      expect(@analytics).to receive(:track_event).
        with('Account Reset: granted token validation', properties)

      travel_to(Time.zone.now + 2.days) do
        get :show, params: { token: AccountResetRequest.first.granted_token }
      end

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(
        t('errors.account_reset.granted_token_expired', app_name: APP_NAME),
      )
    end

    it 'renders the show view if the token is missing' do
      get :show

      expect(response).to render_template(:show)
    end
  end
end
