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

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: {
          backup_codes: BackupCodeGenerator::NUMBER_OF_CODES,
          webauthn: 2,
          phone: 2,
        },
        identity_verified: false,
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      )
      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'redirects to root if the token does not match one in the DB' do
      session[:granted_token] = 'foo'

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: 'anonymous-uuid',
        success: false,
        errors: invalid_token_error,
        error_details: { token: { granted_token_invalid: true } },
        mfa_method_counts: {},
        identity_verified: false,
        account_age_in_days: 0,
        account_confirmed_at: kind_of(Time),
      )
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(invalid_token_message)
    end

    it 'displays a flash and redirects to root if the token is missing' do
      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: 'anonymous-uuid',
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_missing', app_name: APP_NAME)] },
        error_details: { token: { blank: true } },
        mfa_method_counts: {},
        identity_verified: false,
        account_age_in_days: 0,
        account_confirmed_at: kind_of(Time),
      )
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

      travel_to(Time.zone.now + 2.days) do
        session[:granted_token] = AccountResetRequest.first.granted_token
        delete :delete
      end

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)] },
        error_details: { token: { granted_token_expired: true } },
        mfa_method_counts: {},
        identity_verified: false,
        account_age_in_days: 2,
        account_confirmed_at: kind_of(Time),
      )
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(
        t('errors.account_reset.granted_token_expired', app_name: APP_NAME),
      )
    end

    it 'logs info about user verified account' do
      user = create(
        :user,
        :fully_registered,
        confirmed_at: Time.zone.now.round,
        profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
      )

      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)
      session[:granted_token] = AccountResetRequest.first.granted_token

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: {
          phone: 1,
          webauthn: 2,
        },
        identity_verified: true,
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      )
      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'logs info about user biometrically verified account' do
      user = create(
        :user,
        :fully_registered,
        confirmed_at: Time.zone.now.round,
        profiles: [build(
          :profile, :active, :verified, pii: { first_name: 'Jane' },
                                        idv_level: :unsupervised_with_selfie
        )],
      )

      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)
      session[:granted_token] = AccountResetRequest.first.granted_token

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: {
          phone: 1,
          webauthn: 2,
        },
        identity_verified: true,
        identity_verification_method: 'Biometric',
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      )
      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'logs info about user pending verify by mail account' do
      user = create(
        :user,
        :fully_registered,
        confirmed_at: Time.zone.now.round,
        profiles: [build(:profile, :verify_by_mail_pending, pii: { first_name: 'Jane' })],
      )

      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)
      session[:granted_token] = AccountResetRequest.first.granted_token

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: {
          phone: 1,
          webauthn: 2,
        },
        identity_verified: false,
        identity_verification_method: 'GPO',
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      )
      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end

    it 'logs info about user pending in person verification account' do
      user = create(
        :user,
        :fully_registered,
        :with_pending_in_person_enrollment,
        confirmed_at: Time.zone.now.round,
      )

      create_list(:webauthn_configuration, 2, user: user)
      create_account_reset_request_for(user)
      grant_request(user)
      session[:granted_token] = AccountResetRequest.first.granted_token

      delete :delete

      expect(@analytics).to have_logged_event(
        'Account Reset: delete',
        user_id: user.uuid,
        success: true,
        errors: {},
        mfa_method_counts: {
          phone: 1,
          webauthn: 2,
        },
        identity_verified: false,
        identity_verification_method: 'IPP',
        account_age_in_days: 0,
        account_confirmed_at: user.confirmed_at,
      )
      expect(response).to redirect_to account_reset_confirm_delete_account_url
    end
  end

  describe '#show' do
    it 'redirects to root if the token does not match one in the DB' do
      get :show, params: { token: 'FOO' }

      expect(@analytics).to have_logged_event(
        'Account Reset: granted token validation',
        user_id: 'anonymous-uuid',
        success: false,
        errors: invalid_token_error,
        error_details: { token: { granted_token_invalid: true } },
      )
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq(invalid_token_message)
    end

    it 'displays a flash and redirects to root if the token is expired' do
      user = create(:user)
      create_account_reset_request_for(user)
      grant_request(user)

      travel_to(Time.zone.now + 2.days) do
        get :show, params: { token: AccountResetRequest.first.granted_token }
      end

      expect(@analytics).to have_logged_event(
        'Account Reset: granted token validation',
        user_id: user.uuid,
        success: false,
        errors: { token: [t('errors.account_reset.granted_token_expired', app_name: APP_NAME)] },
        error_details: { token: { granted_token_expired: true } },
      )
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
