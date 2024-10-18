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
      get :index
      expect(@analytics).to have_logged_event(analytics_name)
    end

    it 'does not track page visit if profile is active' do
      profile = create(:profile, :active, :verified)

      stub_sign_in(profile.user)

      get :index

      expect(@analytics).not_to have_logged_event(analytics_name)
    end

    it 'redirects to please call page if fraud review is pending' do
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

    context 'user has active profile' do
      let(:user) { create(:user, :proofed) }
      before do
        stub_sign_in(user)
      end
      it 'redirects to activated' do
        get :index
        expect(response).to redirect_to idv_activated_url
      end

      context 'but user needs to redo idv with facial match' do
        let(:current_sp) { create(:service_provider) }
        before do
          session[:sp] =
            {
              issuer: current_sp.issuer,
              acr_values: Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
            }
        end

        it 'redirects to welcome' do
          get :index
          expect(response).to redirect_to idv_welcome_url
        end

        context 'using vectors of trust' do
          before do
            session[:sp] =
              { issuer: current_sp.issuer, vtr: ['C2.Pb'] }
          end

          it 'redirects to welcome' do
            get :index
            expect(response).to redirect_to idv_welcome_url
          end
        end
      end
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

        expect(response).to redirect_to idv_session_errors_rate_limited_url
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

      it 'redirects the user to start proofing' do
        get :index

        expect(response).to redirect_to idv_welcome_url
      end
    end

    context 'if the number of letter sends has been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          :letter_sends_rate_limited,
          user: user,
        )

        stub_sign_in(profile.user)
      end

      it 'redirects the user to start proofing' do
        get :index

        expect(response).to redirect_to idv_welcome_url
      end
    end

    context 'if the number of letter sends and phone attempts have been exceeded' do
      before do
        user = create(:user)
        profile = create(
          :profile,
          :letter_sends_rate_limited,
          user: user,
        )
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!

        stub_sign_in(profile.user)
      end

      it 'redirects to failure page' do
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

    describe 'SP for IdV requirement' do
      let(:current_sp) { create(:service_provider) }
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      let(:user) { build(:user, password: ControllerHelper::VALID_PASSWORD) }

      before do
        stub_sign_in(user)
        if current_sp.present?
          session[:sp] = { issuer: current_sp.issuer, acr_values: acr_values }
        else
          session[:sp] = {}
        end
        allow(IdentityConfig.store).to receive(:idv_sp_required).and_return(idv_sp_required)
      end

      context 'without an SP context' do
        let(:current_sp) { nil }

        context 'when an SP is required' do
          let(:idv_sp_required) { true }

          it 'redirects back to the account page' do
            get :index
            expect(response).to redirect_to account_url
          end

          it 'begins the proofing process if the user has a profile' do
            create(:profile, :verified, user: user)
            get :index
            expect(response).to redirect_to idv_welcome_url
          end
        end

        context 'no SP required' do
          let(:idv_sp_required) { false }

          it 'begins the identity proofing process' do
            get :index

            expect(response).to redirect_to idv_welcome_url
          end
        end
      end

      context 'with an SP context that does not require IdV' do
        let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

        context 'when an SP is required' do
          let(:idv_sp_required) { true }

          it 'redirects back to the account page' do
            get :index
            expect(response).to redirect_to account_url
          end

          it 'begins the proofing process if the user has a profile' do
            create(:profile, :verified, user: user)
            get :index
            expect(response).to redirect_to idv_welcome_url
          end

          context 'when using semantic acr_values' do
            let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }

            before do
              allow(IdentityConfig).to receive(
                :allowed_valid_authn_context_semantic_providers,
              ).and_return([current_sp])
            end

            it 'redirects back to the account page' do
              get :index
              expect(response).to redirect_to account_url
            end

            it 'begins the proofing process if the user has a profile' do
              create(:profile, :verified, user: user)
              get :index
              expect(response).to redirect_to idv_welcome_url
            end
          end
        end

        context 'no SP required' do
          let(:idv_sp_required) { false }

          it 'begins the identity proofing process' do
            get :index

            expect(response).to redirect_to idv_welcome_url
          end

          context 'when using semantic acr_values' do
            let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }

            before do
              allow(IdentityConfig).to receive(
                :allowed_valid_authn_context_semantic_providers,
              ).and_return([current_sp])
            end

            it 'begins the identity proofing process' do
              get :index

              expect(response).to redirect_to idv_welcome_url
            end
          end
        end
      end

      context 'with an SP context that requires IdV' do
        let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

        context 'when an SP is required' do
          let(:idv_sp_required) { true }

          it 'begins the identity proofing process' do
            get :index
            expect(response).to redirect_to idv_welcome_url
          end

          context 'with semantic acr_values' do
            let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }

            before do
              allow(IdentityConfig).to receive(
                :allowed_valid_authn_context_semantic_providers,
              ).and_return([current_sp])
            end

            context 'when an SP is required' do
              let(:idv_sp_required) { true }

              it 'begins the identity proofing process' do
                get :index
                expect(response).to redirect_to idv_welcome_url
              end
            end
          end
        end

        context 'no SP required' do
          let(:idv_sp_required) { false }

          it 'begins the identity proofing process' do
            get :index

            expect(response).to redirect_to idv_welcome_url
          end

          context 'with semantic acr_values' do
            let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }

            before do
              allow(IdentityConfig).to receive(
                :allowed_valid_authn_context_semantic_providers,
              ).and_return([current_sp])
            end

            it 'begins the identity proofing process' do
              get :index

              expect(response).to redirect_to idv_welcome_url
            end
          end
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

      context 'user still has personal_key in idv_session' do
        it 'redirects user to personal key acknowledgement' do
          user = create(:profile, :active, :verified).user
          idv_session = Idv::Session.new(
            user_session: {},
            current_user: user,
            service_provider: nil,
          )
          allow(controller).to receive(:idv_session).and_return(idv_session)
          stub_sign_in(user)
          idv_session.personal_key = 'a-really-secure-key'

          get :activated

          expect(response).to redirect_to idv_personal_key_url
        end
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
