require 'rails_helper'

RSpec.describe DestructiveAccountReset::RequestController do
  include ActionView::Helpers::DateHelper
  let(:user) { create(:user, :with_authentication_app) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
  end

  context 'when account recovery is enabled' do
    let(:user) { create(:user, :fully_registered) }

    before do
      allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
      stub_sign_in_before_2fa(user)
    end

    %i[show create].each do |action|
      it "blocks direct #{action} access for eligible users" do
        expect(DestructiveAccountReset::CreateRequest).not_to receive(:new)

        action == :show ? get(:show) : post(:create)

        expect(response).to redirect_to(login_two_factor_options_url)
        expect(DestructiveAccountResetRequest.find_by(user: user)).to be_nil
      end
    end

    it 'blocks creation when an account recovery request is already active' do
      create(:account_recovery_request, :waiting, user: user)

      expect { post :create }.not_to change { DestructiveAccountResetRequest.count }
      expect(response).to redirect_to(login_two_factor_options_url)
    end

    it 'preserves active recovery ownership when the feature is disabled' do
      create(:account_recovery_request, :waiting, user: user)
      allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

      expect { post :create }.not_to change { DestructiveAccountResetRequest.count }
      expect(response).to redirect_to(login_two_factor_options_url)
    end

    context 'when the user is ineligible for account recovery' do
      let(:user) { create(:user, :proofed) }

      it 'keeps the legacy request page available' do
        get :show

        expect(response).to render_template(:show)
      end

      it 'allows legacy request creation' do
        expect { post :create }.to change { DestructiveAccountResetRequest.count }.by(1)

        expect(response).to redirect_to(account_reset_confirm_request_url)
      end
    end
  end

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
    it 'reports a rejected service request instead of showing a confirmation' do
      stub_sign_in_before_2fa(user)
      stub_analytics
      service = instance_double(
        DestructiveAccountReset::CreateRequest,
        call: FormResponse.new(success: false, errors: { base: ['account_recovery_required'] }),
      )
      allow(DestructiveAccountReset::CreateRequest).to receive(:new).and_return(service)

      post :create

      expect(response).to redirect_to(login_two_factor_options_url)
      expect(flash[:error]).to eq(t('errors.general'))
      expect(@analytics).to have_logged_event(
        'Account Reset: request',
        success: false,
        errors: { base: ['account_recovery_required'] },
        sms_phone: false,
        totp: true,
        piv_cac: false,
        email_addresses: 1,
      )
    end

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

    context 'when the Yes, continue deletion... button is clicked multiple times' do
      it 'rate limits submission and prevents multiple sms and emails' do
        max_attempts = IdentityConfig.store.account_reset_request_max_attempts
        user = create(:user, :fully_registered)
        stub_sign_in_before_2fa(user)
        stub_analytics

        post :create
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
          .exactly(max_attempts - 1)
          .times
      end
    end

    context 'when the max number of attempts today is exceeded' do
      let(:attempt_window_in_minutes) { 2 }
      let(:max_attempt_window) { 1_440 } # 1 day

      it 'rate limits submission for the day and does not send sms or email' do
        user = create(:user, :fully_registered)
        stub_sign_in_before_2fa(user)
        stub_analytics

        RateLimiter.new(
          rate_limit_type: :account_reset_max_attempts,
          user: user,
        ).increment_to_limited!

        expect(@analytics).to_not have_logged_event(
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
    end

    context 'when returning to deletion page after previous submission expired' do
      it 'allows the user to submit a deletion request' do
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

        travel_to(Time.zone.now + 2.days) do
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
      end
    end
  end
end
