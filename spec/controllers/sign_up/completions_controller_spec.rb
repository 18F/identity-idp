require 'rails_helper'

RSpec.describe SignUp::CompletionsController do
  let(:temporary_email) { 'name@temporary.com' }

  describe '#show' do
    let(:current_sp) { create(:service_provider) }

    context 'user signed in, sp info present' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to account page when SP request URL is not present' do
        user = create(:user, :fully_registered)
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
        }
        get :show

        expect(response).to redirect_to account_url
      end

      context 'IAL1' do
        let(:user) { create(:user, :fully_registered, email: temporary_email) }

        before do
          DisposableDomain.create(name: 'temporary.com')
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            ial2: false,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_received(:track_event).with(
            'User registration: agency handoff visited',
            ial2: false,
            ialmax: nil,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: [:email],
            in_account_creation_flow: false,
          )
        end

        it 'creates a presenter object that is not requesting ial2' do
          expect(assigns(:presenter).ial2_requested?).to eq false
        end
      end

      context 'IAL2' do
        let(:user) do
          create(:user, :fully_registered, profiles: [create(:profile, :verified, :active)])
        end
        let(:pii) { { ssn: '123456789' } }

        before do
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            ial2: true,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(pii, 123)

          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_received(:track_event).with(
            'User registration: agency handoff visited',
            ial2: true,
            ialmax: nil,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: [:email],
            in_account_creation_flow: false,
          )
        end

        it 'creates a presenter object that is requesting ial2' do
          expect(assigns(:presenter).ial2_requested?).to eq true
        end

        context 'user is not identity verified' do
          let(:user) { create(:user) }
          it 'redirects to idv_url' do
            get :show

            expect(response).to redirect_to(idv_url)
          end
        end

        context 'sp requires selfie' do
          let(:selfie_capture_enabled) { true }
          before do
            allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).
              and_return(selfie_capture_enabled)
            subject.session[:sp][:biometric_comparison_required] = 'true'
          end

          context 'user does not have a selfie' do
            it 'redirects to idv_url' do
              get :show

              expect(response).to redirect_to(idv_url)
            end
          end

          context 'selfie capture not enabled' do
            let(:selfie_capture_enabled) { false }

            it 'does not redirect' do
              get :show

              expect(response).to render_template :show
            end
          end
        end
      end

      context 'IALMax' do
        let(:user) do
          create(:user, :fully_registered, profiles: [create(:profile, :verified, :active)])
        end
        let(:pii) { { ssn: '123456789' } }

        before do
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            ial2: false,
            ialmax: true,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(pii, 123)

          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_received(:track_event).with(
            'User registration: agency handoff visited',
            ial2: false,
            ialmax: true,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: [:email],
            in_account_creation_flow: false,
          )
        end

        context 'verified user' do
          it 'creates a presenter object that is requesting ial2' do
            expect(assigns(:presenter).ial2_requested?).to eq true
          end
        end

        context 'unverified user' do
          let(:user) { create(:user) }
          it 'creates a presenter object that is requesting ial2' do
            expect(assigns(:presenter).ial2_requested?).to eq false
          end
        end
      end
    end

    it 'requires user with session to be logged in' do
      subject.session[:sp] = { dog: 'max' }
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires user with no session to be logged in' do
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires service provider or identity info in session' do
      stub_sign_in
      subject.session[:sp] = {}

      get :show

      expect(response).to redirect_to(account_url)
    end

    it 'requires service provider issuer in session' do
      stub_sign_in
      subject.session[:sp] = { issuer: nil }

      get :show

      expect(response).to redirect_to(account_url)
    end

    context 'renders partials' do
      render_views

      it 'renders show if the user has identities and no active session' do
        user = create(:user)
        sp = create(:service_provider, issuer: 'https://awesome')
        stub_sign_in(user)
        subject.session[:sp] = { issuer: sp.issuer,
                                 ial2: false,
                                 requested_attributes: [:email],
                                 request_url: 'http://localhost:3000' }
        get :show

        expect(response).to render_template(:show)
      end
    end
  end

  describe '#update' do
    let(:now) { Time.zone.now.change(usec: 0) }

    before do
      stub_analytics
      allow(@analytics).to receive(:track_event)
      @linker = instance_double(IdentityLinker)
      allow(@linker).to receive(:link_identity).and_return(true)
      allow(IdentityLinker).to receive(:new).and_return(@linker)
    end

    context 'IAL1' do
      let(:user) { create(:user, :fully_registered) }
      it 'tracks analytics' do
        stub_sign_in(user)
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          request_url: 'http://example.com',
        }
        subject.user_session[:in_account_creation_flow] = true

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          'User registration: complete',
          ial2: false,
          ialmax: nil,
          service_provider_name: subject.decorated_sp_session.sp_name,
          page_occurence: 'agency-page',
          needs_completion_screen_reason: :new_sp,
          sp_request_requested_attributes: nil,
          sp_session_requested_attributes: nil,
          in_account_creation_flow: true,
        )
      end

      it 'updates verified attributes' do
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: 'foo',
          ial: 1,
          request_url: 'http://example.com',
          requested_attributes: ['email'],
        }
        expect(@linker).to receive(:link_identity).with(
          ial: 1,
          verified_attributes: ['email'],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        freeze_time do
          travel_to(now)
          patch :update
        end
      end

      it 'redirects to account page if the session request_url is removed' do
        stub_sign_in(user)
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          requested_attributes: ['email'],
        }

        patch :update
        expect(response).to redirect_to account_path
      end

      context 'with a disposable email address' do
        let(:user) { create(:user, :fully_registered, email: temporary_email) }

        it 'logs disposable domain' do
          DisposableDomain.create(name: 'temporary.com')
          stub_sign_in(user)
          subject.session[:sp] = {
            ial2: false,
            issuer: 'foo',
            request_url: 'http://example.com',
          }
          subject.user_session[:in_account_creation_flow] = true

          patch :update

          expect(@analytics).to have_received(:track_event).with(
            'User registration: complete',
            ial2: false,
            ialmax: nil,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: 'agency-page',
            needs_completion_screen_reason: :new_sp,
            sp_request_requested_attributes: nil,
            sp_session_requested_attributes: nil,
            in_account_creation_flow: true,
            disposable_email_domain: 'temporary.com',
          )
        end
      end
    end

    context 'IAL2' do
      it 'tracks analytics' do
        DisposableDomain.create(name: 'temporary.com')
        user = create(
          :user,
          :fully_registered,
          profiles: [create(:profile, :verified, :active)],
          email: temporary_email,
        )
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          ial2: true,
          request_url: 'http://example.com',
          requested_attributes: ['email'],
        }
        subject.user_session[:in_account_creation_flow] = true

        patch :update

        expect(@analytics).to have_received(:track_event).with(
          'User registration: complete',
          ial2: true,
          ialmax: nil,
          service_provider_name: subject.decorated_sp_session.sp_name,
          page_occurence: 'agency-page',
          needs_completion_screen_reason: :new_sp,
          sp_request_requested_attributes: nil,
          sp_session_requested_attributes: ['email'],
          in_account_creation_flow: true,
          disposable_email_domain: 'temporary.com',
        )
      end

      it 'updates verified attributes' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          ial: 2,
          request_url: 'http://example.com',
          requested_attributes: %w[email first_name verified_at],
        }
        expect(@linker).to receive(:link_identity).with(
          ial: 2,
          verified_attributes: %w[email first_name verified_at],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        allow(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey).
          with(user, sp.issuer)
        freeze_time do
          travel_to(now)
          patch :update
        end
      end

      it 'sends the in-person proofing completion survey' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          ial: 2,
          request_url: 'http://example.com',
          requested_attributes: %w[email first_name verified_at],
        }
        allow(@linker).to receive(:link_identity).with(
          ial: 2,
          verified_attributes: %w[email first_name verified_at],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        expect(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey).
          with(user, sp.issuer)
        freeze_time do
          travel_to(now)
          patch :update
        end
      end
    end

    context 'when the user goes through reproofing' do
      let!(:user) { create(:user, profiles: [create(:profile, :active)]) }

      before do
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)
      end

      xit 'does not log a reproofing event during initial proofing' do
        stub_sign_in(user)
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          request_url: 'http://example.com',
        }
        patch :update
      end

      it 'logs a reproofing event upon reproofing' do
        original_profile = user.profiles.first
        additional_profile = create(:profile, :verified, user: user)

        stub_sign_in(user)
        subject.session[:sp] = {
          ial2: false,
          issuer: 'foo',
          request_url: 'http://example.com',
        }

        expect(original_profile.activated_at).to be_present
        expect(original_profile.active).to eq true
        expect(original_profile.deactivation_reason).to be_nil
        expect(original_profile.fraud_review_pending?).to eq(false)
        expect(original_profile.gpo_verification_pending_at).to be_nil
        expect(original_profile.initiating_service_provider).to be_nil
        expect(original_profile.verified_at).to be_present

        expect(additional_profile.activated_at).to be_present
        expect(additional_profile.active).to eq false
        expect(additional_profile.deactivation_reason).to be_nil
        expect(additional_profile.fraud_review_pending?).to eq(false)
        expect(additional_profile.gpo_verification_pending_at).to be_nil
        expect(additional_profile.initiating_service_provider).to be_nil
        expect(additional_profile.verified_at).to be_present

        patch :update
      end

      it 'does not log a reproofing event during account redirect' do
        user.profiles.create(verified_at: Time.zone.now, active: true, activated_at: Time.zone.now)
        stub_sign_in(user)
        subject.session[:sp] = {
          ial2: false,
          request_url: 'http://example.com',
        }

        patch :update

        expect(response).to redirect_to account_path
      end
    end
  end
end
