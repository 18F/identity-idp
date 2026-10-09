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

      context 'auth only' do
        let(:user) { create(:user, :fully_registered, email: temporary_email) }

        before do
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

        it 'creates a presenter object that is not requesting idv' do
          expect(assigns(:presenter).idv_requested?).to eq false
        end
      end

      context 'identity verification' do
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

        it 'creates a presenter object that is requesting idv' do
          expect(assigns(:presenter).idv_requested?).to eq true
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
          it 'creates a presenter object that is requesting idv' do
            expect(assigns(:presenter).idv_requested?).to eq true
          end
        end

        context 'unverified user' do
          let(:user) { create(:user) }
          it 'creates a presenter object that is requesting idv' do
            expect(assigns(:presenter).idv_requested?).to eq false
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
      @linked_identity = instance_double(ServiceProviderIdentity, update!: true)
      allow(@linker).to receive(:link_identity).and_return(@linked_identity)
      allow(IdentityLinker).to receive(:new).and_return(@linker)
    end

    context 'auth only' do
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
        expect(@analytics).to_not have_logged_event(:historic_event_data_released)
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

      context 'when the SP requests document_images and sharing is allowed' do
        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([current_sp.issuer])
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email document_images],
          }
        end

        context 'and the user checks the biometric sharing consent box' do
          it 'records biometric sharing consent and logs the event' do
            expect(@linked_identity).to receive(:update!).with(
              biometric_sharing_consent_at: now,
            )

            freeze_time do
              travel_to(now)
              patch :update, params: { idv_form: { biometric_sharing_consent: '1' } }
            end

            expect(@analytics).to have_logged_event(
              :biometric_sharing_consent_granted,
              issuer: current_sp.issuer,
            )
          end
        end

        context 'and the user does not check the consent box' do
          it 're-renders the handoff with an error and does not link or record consent' do
            expect(@linker).not_to receive(:link_identity)
            expect(@linked_identity).not_to receive(:update!)

            patch :update, params: { idv_form: { biometric_sharing_consent: '0' } }

            expect(response).to have_http_status(:unprocessable_content)
            expect(response).to render_template(:show)
            expect(flash.now[:error])
              .to eq(t('sign_up.document_images_sharing_consent_required'))
            expect(@analytics).to have_logged_event(
              :biometric_sharing_consent_declined,
              issuer: current_sp.issuer,
            )
            expect(@analytics).not_to have_logged_event(:biometric_sharing_consent_granted)
          end

          it 'also rejects when the param is stripped entirely' do
            patch :update

            expect(response).to have_http_status(:unprocessable_content)
          end
        end
      end

      context 'when the SP requests document_images but sharing is not allow-listed' do
        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([])
        end

        it 'does not touch biometric consent and does not log the event' do
          stub_sign_in(user)
          subject.session[:sp] = {
            issuer: current_sp.issuer,
            acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            request_url: 'http://example.com',
            requested_attributes: %w[email document_images],
          }
          expect(@linked_identity).not_to receive(:update!)

          patch :update, params: { idv_form: { biometric_sharing_consent: '1' } }

          expect(@analytics).not_to have_logged_event(:biometric_sharing_consent_granted)
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

    context 'identity verification' do
      it 'tracks analytics' do
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
          in_person_proofing_status: 'passed',
          doc_auth_result: 'Passed',
        )
        expect(@analytics).to_not have_logged_event(:historic_event_data_released)
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
                  profile_id: user.active_profile.id,
                )
              end

              context 'there is no user proofing event' do
                it 'tracks analytics' do
                  patch :update

                  expect(@analytics).to have_logged_event(
                    :historic_event_data_released,
                    success: false,
                    exception: :no_user_proofing_event,
                    profile_id: profile.id,
                  )
                end
              end

              context 'there is a user proofing event' do
                let!(:proofing_event) do
                  create(
                    :user_proofing_event,
                    :existing,
                    profile_id: user.active_profile.id,
                  )
                end

                context 'the profile does not have an encrypted_attempts_file_reference' do
                  it 'tracks analytics' do
                    patch :update

                    expect(@analytics).to have_logged_event(
                      :historic_event_data_released,
                      success: false,
                      exception: :no_encrypted_file_reference,
                      profile_id: profile.id,
                    )
                  end
                end

                context 'the profile has an encrypted_attempts_file_reference' do
                  before do
                    user.active_profile.update(encrypted_attempts_file_reference: 'file-reference')
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

                  it 'tracks analytics' do
                    patch :update

                    expect(@analytics).to have_logged_event(
                      :historic_event_data_released,
                      success: true,
                      profile_id: profile.id,
                    )
                  end
                end
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

    context 'when the broker SP offers token-exchange consent' do
      let(:current_sp) { create(:service_provider, :idv, :active) }
      let(:user) { create(:user, :proofed) }
      let(:broker_identity) do
        create(:service_provider_identity, user: user, service_provider: current_sp.issuer)
      end
      let!(:target_a) do
        create(
          :service_provider, :active, issuer: 'target-a.gov', ial: 2, delegation_application: true,
                                      allowed_delegation_service_providers: [current_sp.issuer]
        )
      end
      let!(:target_b) do
        create(
          :service_provider, :active, issuer: 'target-b.gov', ial: 2, delegation_application: true,
                                      allowed_delegation_service_providers: [current_sp.issuer]
        )
      end
      # Only agencies the user has ALREADY linked are coverable.
      let!(:linked_a) do
        create(:service_provider_identity, user: user, service_provider: 'target-a.gov')
      end
      let!(:linked_b) do
        create(:service_provider_identity, user: user, service_provider: 'target-b.gov')
      end

      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
          .and_return([current_sp.issuer])
        allow(@linker).to receive(:link_identity).and_return(broker_identity)
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
          acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
          request_url: 'http://example.com',
          requested_attributes: %w[email token_exchange],
        }
      end

      def grants
        TokenExchangeGrant.active.where(user: user, broker_issuer: current_sp.issuer)
      end

      def setting
        TokenExchangeBrokerSetting.find_by(user: user, broker_issuer: current_sp.issuer)
      end

      it 'proceeds with nothing granted when the user declines (consent is optional)' do
        patch :update

        expect(response).to_not render_template(:show)
        expect(grants).to be_empty
        expect(@analytics).to have_logged_event(
          :token_exchange_consent_decided,
          issuer: current_sp.issuer, granted: false, all_linked: false, auto_enroll: false,
          target_count: 0
        )
      end

      it 'treats a malformed idv_form param as declined rather than raising' do
        expect { patch :update, params: { idv_form: 'x' } }.not_to raise_error
        expect { patch :update, params: { idv_form: ['x'] } }.not_to raise_error
        expect(grants).to be_empty
      end

      it '"allow all" materializes one grant per currently linked, opted-in agency' do
        patch :update, params: { idv_form: { token_exchange_all: '1' } }

        expect(grants.pluck(:target_issuer)).to match_array(%w[target-a.gov target-b.gov])
        expect(grants.pluck(:granted_at).uniq.size).to eq(1)
        expect(setting&.auto_enroll_enabled?).to be_falsey
        expect(@analytics).to have_logged_event(
          :token_exchange_consent_decided,
          issuer: current_sp.issuer, granted: true, all_linked: true, auto_enroll: false,
          target_count: 2
        )
      end

      it '"allow all" ignores a linked agency that has not opted in to the broker' do
        target_b.update!(allowed_delegation_service_providers: ['other-service-provider.gov'])
        patch :update, params: { idv_form: { token_exchange_all: '1' } }
        expect(grants.pluck(:target_issuer)).to eq(['target-a.gov'])
      end

      it 'auto-enroll records a per-broker setting stamped at consent time' do
        freeze_time do
          patch :update, params: {
            idv_form: { token_exchange_all: '1', token_exchange_auto_enroll: '1' },
          }
          expect(setting.auto_enroll_enabled?).to eq(true)
          expect(setting.auto_enroll_granted_at).to eq(Time.zone.now)
        end
      end

      it 'auto-enroll alone is accepted when the user has no linked agencies' do
        linked_a.destroy!
        linked_b.destroy!
        patch :update, params: { idv_form: { token_exchange_auto_enroll: '1' } }

        expect(response).to_not render_template(:show)
        expect(grants).to be_empty
        expect(setting.auto_enroll_enabled?).to eq(true)
      end

      it 'grants only the chosen, linked, opted-in applications' do
        patch :update, params: {
          idv_form: { token_exchange_targets: ['target-a.gov', 'not-linked.gov'] },
        }

        expect(grants.pluck(:target_issuer)).to eq(['target-a.gov'])
        expect(grants.first.granted_at).to be_present
        expect(grants.first.expires_at).to be_within(1.minute)
          .of(TokenExchangeGrant::GRANT_DURATION.from_now)
      end

      it 'revokes applications dropped when the user changes their choice' do
        TokenExchangeGrant.grant!(
          user: user, broker_issuer: current_sp.issuer, targets: %w[target-a.gov target-b.gov],
        )

        patch :update, params: { idv_form: { token_exchange_targets: ['target-b.gov'] } }

        expect(grants.pluck(:target_issuer)).to eq(['target-b.gov'])
        expect(TokenExchangeGrant.find_by(user: user, target_issuer: 'target-a.gov').revoked_at)
          .to be_present
      end

      it 'preserves existing grants on a return visit that submits the pre-populated form' do
        # The view pre-checks current grants, so a returning user who just
        # continues re-submits them; nothing is silently revoked.
        TokenExchangeGrant.grant!(
          user: user, broker_issuer: current_sp.issuer, targets: %w[target-a.gov],
        )

        patch :update, params: { idv_form: { token_exchange_targets: ['target-a.gov'] } }

        expect(grants.pluck(:target_issuer)).to eq(['target-a.gov'])
        expect(TokenExchangeGrant.find_by(user: user, target_issuer: 'target-a.gov').revoked_at)
          .to be_nil
      end

      it 'ignores auto-enroll without "allow all" when the user has linked agencies' do
        patch :update, params: { idv_form: { token_exchange_auto_enroll: '1' } }
        expect(setting&.auto_enroll_enabled?).to be_falsey
      end

      it 'turns off a previously enabled auto-enroll when the box is left unchecked' do
        TokenExchangeBrokerSetting.for(user: user, broker_issuer: current_sp.issuer)
          .enable_auto_enroll!
        patch :update, params: { idv_form: { token_exchange_all: '1' } }
        expect(setting.auto_enroll_enabled?).to eq(false)
      end
    end

    context 'auto-enrolling a newly connected agency' do
      let(:broker) { create(:service_provider, :idv, :active, issuer: 'broker.gov') }
      let(:current_sp) do
        create(
          :service_provider, :idv, :active, delegation_application: true,
                                            allowed_delegation_service_providers: ['broker.gov']
        )
      end
      let(:user) { create(:user, :proofed) }
      let(:new_identity) do
        create(:service_provider_identity, user: user, service_provider: current_sp.issuer)
      end

      before do
        broker
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
          .and_return(['broker.gov'])
        allow(@linker).to receive(:link_identity).and_return(new_identity)
        stub_sign_in(user)
        subject.session[:sp] = {
          issuer: current_sp.issuer,
          acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
          request_url: 'http://example.com',
          requested_attributes: %w[email],
        }
      end

      it 'grants the new agency to the broker, stamped at the ORIGINAL auto-enroll consent' do
        create(:service_provider_identity, user: user, service_provider: 'broker.gov')
        consent = 2.months.ago.change(usec: 0)
        TokenExchangeBrokerSetting.for(user: user, broker_issuer: 'broker.gov')
          .enable_auto_enroll!(now: consent)

        patch :update

        grant = TokenExchangeGrant.find_by(
          user: user, broker_issuer: 'broker.gov', target_issuer: current_sp.issuer,
        )
        expect(grant).to be_present
        expect(grant.granted_at).to eq(consent)
      end

      it 'does nothing when auto-enroll is off' do
        patch :update
        expect(TokenExchangeGrant.where(user: user)).to be_empty
      end

      it 'does not resurrect an application the user explicitly turned off' do
        create(:service_provider_identity, user: user, service_provider: 'broker.gov')
        TokenExchangeBrokerSetting.for(user: user, broker_issuer: 'broker.gov').enable_auto_enroll!
        TokenExchangeGrant.grant_one!(
          user: user, broker_issuer: 'broker.gov', target_issuer: current_sp.issuer,
        )
        TokenExchangeGrant.revoke!(
          user: user, broker_issuer: 'broker.gov', target_issuer: current_sp.issuer,
        )

        patch :update

        expect(TokenExchangeGrant.active.where(user: user, target_issuer: current_sp.issuer))
          .to be_empty
      end

      it 'does nothing once the broker is no longer connected to the account' do
        TokenExchangeBrokerSetting.for(user: user, broker_issuer: 'broker.gov').enable_auto_enroll!
        # broker identity never created => not in connected_apps
        patch :update
        expect(TokenExchangeGrant.where(user: user)).to be_empty
      end
    end
  end
end
