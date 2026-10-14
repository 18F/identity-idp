require 'rails_helper'

RSpec.describe AccountRecovery::StartController do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(controller).to receive(:ab_test_bucket)
      .with(:NDS_LOOK_AND_FEEL, any_args).and_return(:default)
  end

  describe '#show' do
    it 'redirects to root if the user is not signed in' do
      get :show

      expect(response).to redirect_to root_url
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'renders the page for an eligible user' do
        get :show

        expect(response).to render_template(:show)
      end

      it 'logs the eligibility decision and the visit' do
        stub_analytics

        get :show

        expect(@analytics).to have_logged_event(
          :account_recovery_eligibility_evaluated,
          eligible: true,
          eligibility_reason: AccountRecovery::EligibilityPolicy::ELIGIBLE,
        )
        expect(@analytics).to have_logged_event(:account_recovery_options_visit)
      end

      context 'when the feature is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
        end

        it 'redirects to the legacy account reset flow' do
          get :show

          expect(response).to redirect_to account_reset_recovery_options_url
        end

        it 'logs the ineligibility reason' do
          stub_analytics

          get :show

          expect(@analytics).to have_logged_event(
            :account_recovery_eligibility_evaluated,
            eligible: false,
            eligibility_reason: AccountRecovery::EligibilityPolicy::FEATURE_DISABLED,
          )
        end
      end

      context 'when the user is not fully registered' do
        let(:user) { create(:user, :with_phone) }

        it 'redirects to the legacy account reset flow' do
          get :show

          expect(response).to redirect_to account_reset_recovery_options_url
        end
      end

      context 'when the user is identity proofed' do
        let(:user) { create(:user, :proofed) }

        it 'redirects to the legacy account reset flow' do
          get :show

          expect(response).to redirect_to account_reset_recovery_options_url
        end
      end
    end
  end

  describe '#create' do
    it 'redirects to root if the user is not signed in' do
      post :create

      expect(response).to redirect_to root_url
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      it 'creates a waiting recovery request and redirects to the pending page' do
        post :create

        request = AccountRecoveryRequest.active_for_user(user)
        expect(request).to be_present
        expect(request.state).to eq(AccountRecoveryRequest::WAITING)
        expect(response).to redirect_to account_recovery_pending_url
      end

      it 'logs the request event' do
        stub_analytics

        post :create

        expect(@analytics).to have_logged_event(
          :account_recovery_request,
          success: true,
          eligibility_reason: AccountRecovery::EligibilityPolicy::ELIGIBLE,
          flow_variant: AccountRecoveryRequest::FLOW_VARIANT_ACCOUNT_PRESERVING,
          recovery_state: AccountRecoveryRequest::WAITING,
          rate_limited: false,
        )
      end

      it 'does not mutate MFA configurations' do
        expect { post :create }.to_not change { user.reload.phone_configurations.count }
      end

      context 'when the user is ineligible' do
        let(:user) { create(:user, :proofed) }

        it 'redirects to the legacy flow without creating a request' do
          post :create

          expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
          expect(response).to redirect_to account_reset_recovery_options_url
        end
      end

      context 'when rate limited' do
        before do
          RateLimiter.new(
            rate_limit_type: :account_recovery_request,
            user: user,
          ).increment_to_limited!
        end

        it 'does not create a request and redirects to the legacy flow' do
          post :create

          expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
          expect(response).to redirect_to account_reset_recovery_options_url
        end

        it 'logs the rate limited request' do
          stub_analytics

          post :create

          expect(@analytics).to have_logged_event(
            :account_recovery_request,
            success: false,
            eligibility_reason: AccountRecovery::EligibilityPolicy::ELIGIBLE,
            rate_limited: true,
          )
        end
      end

      context 'when submitted more times than the limit allows' do
        it 'stops creating requests once limited' do
          max_attempts = IdentityConfig.store.account_recovery_request_max_attempts

          (max_attempts + 2).times { post :create }

          expect(AccountRecoveryRequest.where(user: user).count).to be <= max_attempts
        end
      end
    end
  end
end
