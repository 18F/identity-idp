require 'rails_helper'

describe IdvController do
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
      profile = create(:profile, :fraud_review_pending)

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to(idv_please_call_url)
    end

    it 'redirects to fraud rejection page if profile is rejected' do
      profile = create(:profile, :fraud_rejection)

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to(idv_not_verified_url)
    end

    context 'if number of attempts has been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          user: user,
        )
        Throttle.new(throttle_type: :idv_resolution, user: user).increment_to_throttled!

        stub_sign_in(profile.user)
      end

      it 'redirects to failure page' do
        get :index

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end

    it 'redirects to account recovery if user has a password reset profile' do
      profile = create(:profile, :password_reset)
      stub_sign_in(profile.user)
      allow(subject.reactivate_account_session).to receive(:started?).and_return(true)

      get :index

      expect(response).to redirect_to reactivate_account_url
    end

    it 'redirects to doc auth if doc auth is enabled and exclusive' do
      get :index

      expect(response).to redirect_to idv_doc_auth_path
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

            expect(response).to redirect_to idv_doc_auth_url
          end
        end
      end

      context 'sp not required' do
        let(:idv_sp_required) { false }

        it 'begins the identity proofing process' do
          get :index

          expect(response).to redirect_to idv_doc_auth_url
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
