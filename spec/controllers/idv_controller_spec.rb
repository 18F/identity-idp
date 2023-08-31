require 'rails_helper'

RSpec.describe IdvController do
  before do
    stub_sign_in
  end

  describe '#index' do
    let(:analytics_name) { 'IdV: intro visited' }
    before do
      stub_analytics
    end

    it 'tracks page visit' do
      expect(@analytics).to receive(:track_event).with(analytics_name)

      get :index
    end

    it 'does not track page visit if profile is active' do
      profile = create(:profile, :active, :verified)

      stub_sign_in(profile.user)

      expect(@analytics).to_not receive(:track_event).with(analytics_name)

      get :index
    end

    it 'redirects to sad face page if fraud review is pending' do
      profile = create(
        :profile,
        fraud_state: 'fraud_review_pending',
        fraud_review_pending_at: 1.day.ago,
      )

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to(idv_please_call_url)
    end

    it 'redirects to fraud rejection page if profile is rejected' do
      profile = create(
        :profile,
        fraud_state: 'fraud_rejection',
        fraud_rejection_at: 1.day.ago,
      )

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to(idv_not_verified_url)
    end

    context 'if number of verify_info attempts has been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          user: user,
        )
        RateLimiter.new(rate_limit_type: :idv_resolution, user: user).increment_to_limited!

        stub_sign_in(profile.user)
      end

      it 'redirects to failure page' do
        get :index

        expect(response).to redirect_to idv_session_errors_failure_url
      end

      it 'logs appropriate attempts event' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:idv_verification_rate_limited).
          with({ throttle_context: 'single-session' })

        get :index
      end
    end

    context 'if number of document capture attempts has been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          user: user,
        )
        RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment_to_limited!

        stub_sign_in(profile.user)
      end

      it 'redirects to rate limited page' do
        get :index

        expect(response).to redirect_to idv_session_errors_throttled_url
      end
    end

    context 'if number of verify phone attempts has been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          user: user,
        )
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!

        stub_sign_in(profile.user)
      end

      it 'redirects to rate limited page' do
        get :index

        expect(response).to redirect_to idv_phone_errors_failure_url
      end
    end

    it 'redirects to account recovery if user has a password reset profile' do
      profile = create(:profile, :verified, :password_reset)
      stub_sign_in(profile.user)
      allow(subject.reactivate_account_session).to receive(:started?).and_return(true)

      get :index

      expect(response).to redirect_to reactivate_account_url
    end

    it 'redirects to welcome page if doc auth is enabled and exclusive' do
      get :index

      expect(response).to redirect_to idv_welcome_path
    end

    context 'no SP context' do
      let(:user) { build(:user, password: ControllerHelper::VALID_PASSWORD) }

      before do
        stub_sign_in(user)
        session[:sp] = {}
        allow(IdentityConfig.store).to receive(:idv_sp_required).and_return(idv_sp_required)
      end

      context 'sp required' do
        let(:idv_sp_required) { true }

        it 'redirects back to the account page' do
          get :index

          expect(response).to redirect_to account_url
        end

        context 'user has an existing profile' do
          let(:user) do
            profile = create(:profile)
            profile.user
          end

          it 'begins the identity proofing process' do
            get :index

            expect(response).to redirect_to idv_welcome_url
          end
        end
      end

      context 'sp not required' do
        let(:idv_sp_required) { false }

        it 'begins the identity proofing process' do
          get :index

          expect(response).to redirect_to idv_welcome_url
        end
      end
    end
  end

  describe '#activated' do
    context 'user has an active profile' do
      it 'allows direct access' do
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        get :activated

        expect(response).to render_template(:activated)
      end
    end

    context 'user does not have an active profile' do
      it 'does not allow direct access' do
        get :activated

        expect(response).to redirect_to idv_url
      end
    end
  end
end
