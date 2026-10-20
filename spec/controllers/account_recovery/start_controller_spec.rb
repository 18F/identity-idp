require 'rails_helper'

RSpec.describe AccountRecovery::StartController do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(controller).to receive(:ab_test_bucket)
      .with(:NDS_LOOK_AND_FEEL, any_args).and_return(:default)
  end

  [
    AccountRecoveryRequest::REQUESTED,
    AccountRecoveryRequest::WAITING,
    AccountRecoveryRequest::GRANTED,
  ].each do |state|
    context "with an existing #{state} request" do
      let!(:recovery_request) do
        create(:account_recovery_request, :granted, state: state, user: user)
      end

      before { stub_sign_in_before_2fa(user) }

      it 'returns to pending rather than restarting recovery' do
        get :show

        expect(response).to redirect_to(account_recovery_pending_status_url)
      end

      it 'does not create a duplicate request or send another email on resubmission' do
        expect do
          post :create
        end.not_to change { AccountRecoveryRequest.count }
        expect(ActionMailer::Base.deliveries).to be_empty
        expect(recovery_request.reload.state).to eq(state)
        expect(response).to redirect_to(account_recovery_pending_status_url)
      end
    end
  end

  it 'does not resume another user’s request' do
    stub_sign_in_before_2fa(user)
    create(:account_recovery_request, :waiting)

    get :show

    expect(response).to render_template(:show)
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
        )
        expect(@analytics).to have_logged_event(:account_recovery_options_visit)
      end

      context 'when the feature is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
        end

        it 'returns to authentication options with an error' do
          get :show

          expect(response).to redirect_to login_two_factor_options_url
          expect(flash[:error]).to eq(t('account_recovery.start.unavailable'))
        end

        it 'logs the ineligibility reason' do
          stub_analytics

          get :show

          expect(@analytics).to have_logged_event(
            :account_recovery_eligibility_evaluated,
            eligible: false,
          )
        end
      end

      context 'when the user is not fully registered' do
        let(:user) { create(:user, :with_phone) }

        it 'returns to authentication options with an error' do
          get :show

          expect(response).to redirect_to login_two_factor_options_url
          expect(flash[:error]).to eq(t('account_recovery.start.unavailable'))
        end
      end

      context 'when the user is identity proofed' do
        let(:user) { create(:user, :proofed) }

        it 'returns to authentication options with an error' do
          get :show

          expect(response).to redirect_to login_two_factor_options_url
          expect(flash[:error]).to eq(t('account_recovery.start.unavailable'))
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
          recovery_state: AccountRecoveryRequest::WAITING,
          rate_limited: false,
        )
      end

      it 'does not mutate MFA configurations' do
        expect { post :create }.to_not change { user.reload.phone_configurations.count }
      end

      it 'reports a failed request without redirecting to account deletion' do
        service = instance_double(AccountRecovery::CreateRequest)
        allow(AccountRecovery::CreateRequest).to receive(:new).with(user: user).and_return(service)
        allow(service).to receive(:call).and_return(FormResponse.new(success: false))

        post :create

        expect(response).to redirect_to login_two_factor_options_url
        expect(flash[:error]).to eq(t('errors.general'))
        expect(AccountRecoveryRequest.active_for_user(user)).to be_nil
      end

      context 'when the user is ineligible' do
        let(:user) { create(:user, :proofed) }

        it 'returns to authentication options without creating a request' do
          post :create

          expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
          expect(response).to redirect_to login_two_factor_options_url
          expect(flash[:error]).to eq(t('account_recovery.start.unavailable'))
        end
      end

      context 'when rate limited' do
        before do
          RateLimiter.new(
            rate_limit_type: :account_recovery_request,
            user: user,
          ).increment_to_limited!
        end

        it 'does not create a request and returns to the recovery start page' do
          post :create

          expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
          expect(response).to redirect_to account_recovery_start_url
          expect(flash[:error]).to eq(t('account_recovery.start.rate_limited'))
        end

        it 'logs the rate limited request' do
          stub_analytics

          post :create

          expect(@analytics).to have_logged_event(
            :account_recovery_request,
            success: false,
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
