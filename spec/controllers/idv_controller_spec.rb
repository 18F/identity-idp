require 'rails_helper'

describe IdvController do
  describe '#index' do
    it 'tracks page visit' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end

    it 'does not track page visit if profile is active' do
      profile = create(:profile, :active, :verified)

      stub_sign_in(profile.user)
      stub_analytics

      expect(@analytics).to_not receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end

    it 'redirects to failure page if number of attempts has been exceeded' do
      user = create(:user)
      profile = create(
        :profile,
        user: user,
      )
      Throttle.create(throttle_type: 5, user_id: user.id, attempts: 5, attempted_at: Time.zone.now)

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to idv_session_errors_failure_url
    end

    it 'redirects to account recovery if user has a password reset profile' do
      profile = create(:profile, deactivation_reason: :password_reset)
      stub_sign_in(profile.user)
      allow(subject.reactivate_account_session).to receive(:started?).and_return(true)

      get :index

      expect(response).to redirect_to reactivate_account_url
    end

    it 'redirects to doc auth if doc auth is enabled and exclusive' do
      stub_sign_in

      get :index

      expect(response).to redirect_to idv_doc_auth_path
    end

    context 'sp has reached quota limit' do
      let(:issuer) { 'foo' }

      it 'does not allow user to be verified and redirects to account url with error message' do
        stub_sign_in
        ServiceProviderQuotaLimit.create(issuer: issuer, ial: 2, percent_full: 100)
        session[:sp] = { issuer: issuer, ial: 2 }

        get :index

        expect(flash[:error]).to eq t('errors.doc_auth.quota_reached')
        expect(response).to redirect_to account_url
      end
    end

    context 'no SP context' do
      let(:user) { build(:user, password: ControllerHelper::VALID_PASSWORD) }

      before do
        stub_sign_in(user)
        session[:sp] = {}
        allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)
        allow(IdentityConfig.store).to receive(:sp_context_needed_environment).and_return('prod')
      end

      context 'prod environment' do
        before do
          allow(Identity::Hostdata).to receive(:env).and_return('prod')
        end

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

      context 'non-prod environment' do
        before do
          allow(Identity::Hostdata).to receive(:env).and_return('staging')
        end

        it 'begins the identity proofing process' do
          get :index

          expect(response).to redirect_to idv_doc_auth_url
        end
      end

      context 'local development' do
        before do
          allow(Identity::Hostdata).to receive(:env).and_return(nil)
          allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(false)
        end

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
        expect(subject.idv_session.alive?).to eq false
      end
    end

    context 'user does not have an active profile' do
      it 'does not allow direct access' do
        stub_sign_in

        get :activated

        expect(response).to redirect_to idv_url
      end
    end
  end
end
