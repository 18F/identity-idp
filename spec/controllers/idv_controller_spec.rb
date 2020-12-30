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
      Throttle.create(throttle_type: 5, user_id: user.id, attempts: 3, attempted_at: Time.zone.now)

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to idv_fail_url
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
      before do
        stub_sign_in
        session[:sp] = {}
      end

      context 'prod environment' do
        before do
          allow(LoginGov::Hostdata).to receive(:env).and_return('prod')
          allow(LoginGov::Hostdata).to receive(:in_datacenter?).and_return(true)
        end

        it 'redirects back to the account page' do
          get :index

          expect(response).to redirect_to account_url
        end
      end

      context 'non-prod environment' do
        before do
          allow(LoginGov::Hostdata).to receive(:env).and_return('staging')
          allow(LoginGov::Hostdata).to receive(:in_datacenter?).and_return(true)
        end

        it 'begins the identity proofing process' do
          get :index

          expect(response).to redirect_to idv_doc_auth_url
        end
      end


      context 'local development' do
        before do
          allow(LoginGov::Hostdata).to receive(:env).and_return('prod')
          allow(LoginGov::Hostdata).to receive(:in_datacenter?).and_return(false)
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

  describe '#fail' do
    context 'user has an active profile' do
      it 'does not allow direct access and redirects to activated url' do
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        get :fail

        expect(response).to redirect_to idv_activated_url
      end
    end

    context 'user does not have an active profile and has not exceeded IdV attempts' do
      it 'does not allow direct access and redirects to the main IdV page' do
        stub_sign_in

        get :fail

        expect(response).to redirect_to idv_url
      end
    end

    context 'user does not have an active profile and has exceeded IdV attempts' do
      let(:user) { create(:user) }

      before do
        profile = create(
          :profile,
          user: user,
        )
        Throttle.create(
          throttle_type: 5,
          user_id: user.id,
          attempts: 3,
          attempted_at: Time.zone.now,
        )

        stub_sign_in(profile.user)
      end

      it 'allows direct access' do
        get :fail

        expect(response).to render_template('idv/fail')
      end

      context 'when there is an SP in the session' do
        render_views

        let(:service_provider) do
          create(:service_provider, failure_to_proof_url: 'https://foo.bar')
        end

        before do
          session[:sp] = { issuer: service_provider.issuer }
        end

        it "includes a link back to the SP's failure to proof URL" do
          get :fail

          expect(response.body).to include('https://foo.bar')
        end
      end
    end
  end
end
