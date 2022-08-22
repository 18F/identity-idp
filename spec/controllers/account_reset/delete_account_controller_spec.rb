require 'rails_helper'

describe AccountReset::DeleteAccountController do
  include AccountResetHelper

  describe '#delete' do
    it 'logs a good token to the analytics' do
      user = create(:user, :signed_up, :with_backup_code)
      create(:phone_configuration, user: user, phone: Faker::PhoneNumber.cell_phone)
      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)

      session[:granted_token] = AccountResetRequest.first.granted_token
      stub_analytics
      properties = {
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: { backup_codes: 10, webauthn: 2, phone: 2 },
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
      }
      expect(@analytics).
        to receive(:track_event).with('Account Reset: delete', properties)

      delete :delete

      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'logs a good token to the attempts api' do
      user = create(:user, :signed_up, :with_backup_code)
      create(:phone_configuration, user: user, phone: Faker::PhoneNumber.cell_phone)
      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)

      session[:granted_token] = AccountResetRequest.first.granted_token
      stub_attempts_tracker

      expect(@irs_attempts_api_tracker).to receive(:account_reset_account_deleted).with(
        success: true,
        failure_reason: {},
      )

      delete :delete

      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'redirects to root if the token does not match one in the DB' do
      session[:granted_token] = 'foo'
      stub_analytics
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_invalid', app_name: APP_NAME)] },
        error_details: {
          token: [t('errors.account_reset.granted_token_invalid', app_name: APP_NAME)],
        },
        mfa_method_counts: {},
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
      }
      expect(@analytics).to receive(:track_event).with('Account Reset: delete', properties)

      delete :delete

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(
        t('errors.account_reset.granted_token_invalid', app_name: APP_NAME),
      )
    end

    it 'logs an error in irs attempts tracker' do
      session[:granted_token] = 'foo'
      stub_attempts_tracker
      properties = {
        success: false,
        failure_reason: { token: [t(
          'errors.account_reset.granted_token_invalid',
          app_name: APP_NAME,
        )] },
      }
      expect(@irs_attempts_api_tracker).to receive(:account_reset_account_deleted).with(
        properties,
      )

      delete :delete
    end

    it 'displays a flash and redirects to root if the token is missing' do
      stub_analytics
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_missing', app_name: APP_NAME)] },
        error_details: { token: [:blank] },
        mfa_method_counts: {},
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        account_age_in_days: 0,
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

      stub_analytics
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
      stub_analytics
      properties = {
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_invalid', app_name: APP_NAME)] },
        error_details: {
          token: [t('errors.account_reset.granted_token_invalid', app_name: APP_NAME)],
        },
      }
      expect(@analytics).to receive(:track_event).
        with('Account Reset: granted token validation', properties)

      get :show, params: { token: 'FOO' }

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(
        t('errors.account_reset.granted_token_invalid', app_name: APP_NAME),
      )
    end

    it 'displays a flash and redirects to root if the token is expired' do
      user = create(:user)
      create_account_reset_request_for(user)
      grant_request(user)

      stub_analytics
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
