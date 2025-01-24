require 'rails_helper'

RSpec.describe AccountReset::RequestController do
  include ActionView::Helpers::DateHelper
  let(:user) { create(:user, :with_authentication_app) }
  describe '#show' do
    it 'renders the page' do
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to render_template(:show)
    end

    it 'redirects to root if user not signed in' do
      get :show

      expect(response).to redirect_to root_url
    end

    it 'redirects to 2FA setup url if 2FA not set up' do
      stub_sign_in_before_2fa
      get :show

      expect(response).to redirect_to authentication_methods_setup_url
    end

    it 'logs the visit to analytics' do
      stub_sign_in_before_2fa(user)
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event('Account deletion and reset visited')
    end

    context 'non-fraud user' do
      it 'should have @account_reset_deletion_period_interval to match regular wait period' do
        stub_sign_in_before_2fa(user)

        get :show
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_wait_period_days.days,
          true,
          accumulate_on: :hours,
        )
        expect(controller.view_assigns['account_reset_deletion_period_interval'])
          .to eq(time_in_hours)
      end
    end

    context 'fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }

      context 'fraud wait period not set' do
        before do
          allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
            .and_return(nil)
        end

        it 'should have @account_reset_deletion_period to match regular wait period' do
          stub_sign_in_before_2fa(user)

          get :show
          current_time = Time.zone.now
          time_in_hours = distance_of_time_in_words(
            current_time,
            current_time + IdentityConfig.store.account_reset_wait_period_days.days,
            true,
            accumulate_on: :hours,
          )
          expect(controller.view_assigns['account_reset_deletion_period_interval'])
            .to eq(time_in_hours)
        end
      end

      it 'should have @account_reset_deletion_period_interval to match fraud wait period' do
        stub_sign_in_before_2fa(user)

        get :show
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_fraud_user_wait_period_days.days,
          true,
          accumulate_on: :days,
        )
        expect(controller.view_assigns['account_reset_deletion_period_interval'])
          .to eq(time_in_hours)
      end
    end
  end

  describe '#create' do
    it 'logs totp user in the analytics' do
      stub_sign_in_before_2fa(user)
      stub_analytics

      post :create

      expect(@analytics).to have_logged_event(
        'Account Reset: request',
        success: true,
        sms_phone: false,
        totp: true,
        piv_cac: false,
        email_addresses: 1,
      )
    end

    it 'logs sms user in the analytics' do
      user = create(:user, :fully_registered)
      stub_sign_in_before_2fa(user)
      stub_analytics

      post :create

      expect(@analytics).to have_logged_event(
        'Account Reset: request',
        success: true,
        sms_phone: true,
        totp: false,
        piv_cac: false,
        email_addresses: 1,
        request_id: 'fake-message-request-id',
        message_id: 'fake-message-id',
      )
    end

    it 'logs PIV/CAC user in the analytics' do
      user = create(:user, :with_piv_or_cac, :with_backup_code)
      stub_sign_in_before_2fa(user)
      stub_analytics

      post :create

      expect(@analytics).to have_logged_event(
        'Account Reset: request',
        success: true,
        sms_phone: false,
        totp: false,
        piv_cac: true,
        email_addresses: 1,
      )
    end

    it 'redirects to root if user not signed in' do
      post :create

      expect(response).to redirect_to root_url
    end

    it 'redirects to 2FA setup url if 2FA not set up' do
      stub_sign_in_before_2fa
      post :create

      expect(response).to redirect_to authentication_methods_setup_url
    end
  end
end
