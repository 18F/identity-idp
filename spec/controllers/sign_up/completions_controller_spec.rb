require 'rails_helper'

RSpec.describe SignUp::CompletionsController do
  let(:temporary_email) { 'name@temporary.com' }
  let(:current_sp) { create(:service_provider) }

  describe '#show' do
    context 'user signed in, sp info present' do
      before do
        stub_analytics
      end

      it 'redirects to account page when SP request URL is not present' do
        user = create(:user, :fully_registered)
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        }
        get :show

        expect(response).to redirect_to account_url
      end

      context 'IAL1' do
        let(:user) { create(:user, :fully_registered, email: temporary_email) }

        before do
          DisposableEmailDomain.create(name: 'temporary.com')
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_logged_event(
            'User registration: agency handoff visited',
            ial2: false,
            ialmax: false,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
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
            acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(pii, 123)

          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_logged_event(
            'User registration: agency handoff visited',
            ial2: true,
            ialmax: false,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
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
            acr_values: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
            requested_attributes: [:email],
            request_url: 'http://localhost:3000',
          }
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(pii, 123)

          get :show
        end

        it 'tracks page visit' do
          expect(@analytics).to have_logged_event(
            'User registration: agency handoff visited',
            ial2: false,
            ialmax: true,
            service_provider_name: subject.decorated_sp_session.sp_name,
            page_occurence: '',
            needs_completion_screen_reason: :new_sp,
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
        subject.session[:sp] = {
          issuer: sp.issuer,
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          requested_attributes: [:email],
          request_url: 'http://localhost:3000',
        }

        get :show

        expect(response).to render_template(:show)
      end
    end
  end

  describe '#update' do
    let(:now) { Time.zone.now.change(usec: 0) }

    before do
      stub_analytics
      @linker = instance_double(IdentityLinker)
      allow(@linker).to receive(:link_identity).and_return(true)
      allow(IdentityLinker).to receive(:new).and_return(@linker)
    end

    context 'IAL1' do
      let(:user) { create(:user, :fully_registered) }
      it 'tracks analytics' do
        stub_sign_in(user)
        subject.session[:sp] = {
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          issuer: current_sp.issuer,
          request_url: 'http://example.com',
        }
        subject.user_session[:in_account_creation_flow] = true

        patch :update

        expect(@analytics).to have_logged_event(
          'User registration: complete',
          ial2: false,
          ialmax: false,
          page_occurence: 'agency-page',
          service_provider_name: current_sp.friendly_name,
          needs_completion_screen_reason: :new_sp,
          in_account_creation_flow: true,
        )
      end

      it 'updates verified attributes' do
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
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
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          issuer: current_sp.issuer,
          requested_attributes: ['email'],
        }

        patch :update
        expect(response).to redirect_to account_path
      end

      it 'replaces a stale selected email session value with the last sign in email' do
        stale_email = create(:email_address, user: user, confirmed_at: nil)

        stub_sign_in(user)
        subject.session[:sp] = {
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          issuer: current_sp.issuer,
          request_url: 'http://example.com',
        }
        subject.user_session[:selected_email_id_for_linked_identity] = stale_email.id

        patch :update

        expect(subject.user_session[:selected_email_id_for_linked_identity].to_i).to eq(
          user.last_sign_in_email_address.id,
        )
      end

      context 'with a disposable email address' do
        let(:user) { create(:user, :fully_registered, email: temporary_email) }

        it 'logs disposable domain' do
          DisposableEmailDomain.create(name: 'temporary.com')
          stub_sign_in(user)
          subject.session[:sp] = {
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            issuer: current_sp.issuer,
            request_url: 'http://example.com',
          }
          subject.user_session[:in_account_creation_flow] = true

          patch :update

          expect(@analytics).to have_logged_event(
            'User registration: complete',
            ial2: false,
            ialmax: false,
            page_occurence: 'agency-page',
            needs_completion_screen_reason: :new_sp,
            service_provider_name: current_sp.friendly_name,
            in_account_creation_flow: true,
            disposable_email_domain: 'temporary.com',
          )
        end
      end

      context 'with unconfirmed email addresses' do
        it 'does not send email to unconfirmed email addresses' do
          user = create(:user, :fully_registered)
          create(:email_address, user: user, confirmed_at: nil)
          stub_sign_in(user)
          subject.session[:sp] = {
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            issuer: current_sp.issuer,
            request_url: 'http://example.com',
          }

          patch :update
          user.reload
          expect(user.email_addresses.count).to eq(2)
          expect_delivered_email_count(1)
        end
      end
    end

    context 'IAL2' do
      it 'tracks analytics' do
        DisposableEmailDomain.create(name: 'temporary.com')
        user = create(
          :user,
          :fully_registered,
          profiles: [create(:profile, :verified, :active)],
          email: temporary_email,
        )
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        create(:in_person_enrollment, status: 'passed', doc_auth_result: 'Passed', user: user)
        subject.session[:sp] = {
          issuer: sp.issuer,
          acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          request_url: 'http://example.com',
          requested_attributes: ['email'],
        }
        subject.user_session[:in_account_creation_flow] = true

        patch :update

        expect(@analytics).to have_logged_event(
          'User registration: complete',
          ial2: true,
          ialmax: false,
          service_provider_name: subject.decorated_sp_session.sp_name,
          page_occurence: 'agency-page',
          needs_completion_screen_reason: :new_sp,
          sp_session_requested_attributes: ['email'],
          in_account_creation_flow: true,
          disposable_email_domain: 'temporary.com',
          in_person_proofing_status: 'passed',
          doc_auth_result: 'Passed',
        )
      end

      it 'updates verified attributes' do
        user = create(:user, profiles: [create(:profile, :verified, :active)])
        stub_sign_in(user)
        sp = create(:service_provider, issuer: 'https://awesome')
        subject.session[:sp] = {
          issuer: sp.issuer,
          acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          request_url: 'http://example.com',
          requested_attributes: %w[email first_name verified_at],
        }
        expect(@linker).to receive(:link_identity).with(
          ial: 2,
          verified_attributes: %w[email first_name verified_at],
          last_consented_at: now,
          clear_deleted_at: true,
        )
        allow(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey)
          .with(user, sp.issuer)
        freeze_time do
          travel_to(now)
          patch :update
        end
      end

      context 'historical attempts api is enabled' do
        let(:profile) { create(:profile, :verified, :active) }
        let(:user) { create(:user, profiles: [profile]) }
        let(:current_sp) { create(:service_provider, :idv, :active) }
        let(:allowed_attempts_providers) { [{ 'issuer' => current_sp.issuer }] }

        before do
          allow(IdentityConfig.store).to receive_messages(
            attempts_api_enabled: true,
            historical_attempts_api_enabled: true,
            allowed_attempts_providers:,
          )
        end

        context 'user has existing proofing events' do
          let(:service_provider_ids_sent) { [] }

          let(:proofing_event) do
            create(
              :user_proofing_event,
              :existing,
              profile_id: profile.id,
              service_provider_ids_sent:,
            )
          end
          let(:idv_attempts) do
            [
              { 'idv-ssn-submitted' => { 'user_uuid' => user.uuid } },
            ].to_json
          end

          before do
            allow(AttemptsApi::Tracker).to receive(:write_existing_user_events)

            stub_sign_in(user)

            subject.session[:sp] = {
              issuer: current_sp.issuer,
              acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
              request_url: 'http://example.com',
              requested_attributes: %w[email first_name verified_at],
            }

            kms_encrypted_events = SessionEncryptor.new.kms_encrypt(idv_attempts)
            subject.user_session[:encrypted_proofing_events] = kms_encrypted_events
          end

          context 'service_provider is an allowed attempts provider' do
            context 'user proofing events have not been sent to this SP' do
              let(:proofing_event) do
                create(
                  :user_proofing_event,
                  :existing,
                  profile_id: profile.id,
                )
              end

              it 'updates the associated user proofing event' do
                expect(proofing_event.service_provider_ids_sent).to_not include(current_sp.id)
                patch :update

                proofing_event.reload
                expect(AttemptsApi::Tracker).to have_received(:write_existing_user_events).with(
                  historical_attempts: JSON.parse(idv_attempts),
                  sp: current_sp,
                )
                expect(proofing_event.service_provider_ids_sent).to include(current_sp.id)
              end
            end

            context 'user proofing events have already been sent to this SP' do
              let(:service_provider_ids_sent) { [current_sp.id] }

              it 'does not update the user proofing event' do
                patch :update

                expect(AttemptsApi::Tracker).to_not have_received(:write_existing_user_events)

                proofing_event.reload
                expect(proofing_event.service_provider_ids_sent).to eq([current_sp.id])
              end
            end
          end

          context 'issuer is not an allowed attempts provider' do
            let(:allowed_attempts_providers) { [] }

            it 'does not update the user proofing event' do
              patch :update

              expect(AttemptsApi::Tracker).to_not have_received(:write_existing_user_events)
              expect(UserProofingEvent.find(proofing_event.id).service_provider_ids_sent)
                .to_not include(current_sp.issuer)
            end
          end
        end
      end

      context 'in person completion survey delievery enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_completion_survey_delivery_enabled)
            .and_return(true)
        end

        it 'sends the in-person proofing completion survey' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          sp = create(
            :service_provider, issuer: 'https://awesome',
                               in_person_proofing_enabled: true
          )

          subject.session[:sp] = {
            issuer: sp.issuer,
            acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email first_name verified_at],
          }
          allow(@linker).to receive(:link_identity).with(
            verified_attributes: %w[email first_name verified_at],
            last_consented_at: now,
            clear_deleted_at: true,
          )
          expect(Idv::InPerson::CompletionSurveySender).to receive(:send_completion_survey)
            .with(user, sp.issuer)
          freeze_time do
            travel_to(now)
            patch :update
          end
        end

        it 'updates follow_up_survey_sent on enrollment to true' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          sp = create(
            :service_provider, issuer: 'https://awesome',
                               in_person_proofing_enabled: true
          )
          e = create(
            :in_person_enrollment, status: 'passed', doc_auth_result: 'Passed',
                                   user: user, issuer: sp.issuer
          )

          expect(e.follow_up_survey_sent).to be false

          subject.session[:sp] = {
            issuer: sp.issuer,
            acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email first_name verified_at],
          }
          allow(@linker).to receive(:link_identity).with(
            verified_attributes: %w[email first_name verified_at],
            last_consented_at: now,
            clear_deleted_at: true,
          )

          patch :update
          e.reload

          expect(e.follow_up_survey_sent).to be true
        end
      end

      context 'in person completion survey delievery disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_completion_survey_delivery_enabled)
            .and_return(false)
        end

        it 'does not send the in-person proofing completion survey' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          sp = create(
            :service_provider, issuer: 'https://awesome',
                               in_person_proofing_enabled: true
          )

          subject.session[:sp] = {
            issuer: sp.issuer,
            acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email first_name verified_at],
          }
          allow(@linker).to receive(:link_identity).with(
            verified_attributes: %w[email first_name verified_at],
            last_consented_at: now,
            clear_deleted_at: true,
          )
          expect(Idv::InPerson::CompletionSurveySender).not_to receive(:send_completion_survey)
            .with(user, sp.issuer)
          freeze_time do
            travel_to(now)
            patch :update
          end
        end

        it 'does not update enrollment' do
          user = create(:user, profiles: [create(:profile, :verified, :active)])
          stub_sign_in(user)
          sp = create(
            :service_provider, issuer: 'https://awesome',
                               in_person_proofing_enabled: true
          )
          e = create(
            :in_person_enrollment, status: 'passed', doc_auth_result: 'Passed',
                                   user: user, issuer: sp.issuer
          )

          expect(e.follow_up_survey_sent).to be false

          subject.session[:sp] = {
            issuer: sp.issuer,
            acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email first_name verified_at],
          }
          allow(@linker).to receive(:link_identity).with(
            verified_attributes: %w[email first_name verified_at],
            last_consented_at: now,
            clear_deleted_at: true,
          )

          patch :update
          e.reload

          expect(e.follow_up_survey_sent).to be false
        end
      end
    end
  end
end
