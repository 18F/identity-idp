require 'rails_helper'

describe Idv::ReviewController do
  include UspsIppHelper

  let(:user) do
    create(
      :user,
      :signed_up,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'old_email@example.com',
    )
  end
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:idv_session) do
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      service_provider: nil,
    )
    idv_session.profile_confirmation = true
    idv_session.vendor_phone_confirmation = true
    idv_session.applicant = applicant.with_indifferent_access
    idv_session
  end

  before do
    stub_analytics
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_steps_complete,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#confirm_idv_steps_complete' do
    controller do
      before_action :confirm_idv_steps_complete

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'idv/review#show'
      end
    end

    context 'user has missed address step' do
      before do
        idv_session.vendor_phone_confirmation = false
      end

      it 'redirects to address step' do
        get :show

        expect(response).to redirect_to idv_phone_path
      end
    end
  end

  describe '#confirm_idv_phone_confirmed' do
    controller do
      before_action :confirm_idv_phone_confirmed

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      routes.draw do
        get 'show' => 'idv/review#show'
      end
    end

    context 'user is verifying by mail' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('gpo')
      end

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'user phone is confirmed' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('phone')
        allow(idv_session).to receive(:phone_confirmed?).and_return(true)
      end

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'user phone is not confirmed' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('phone')
        allow(idv_session).to receive(:phone_confirmed?).and_return(false)
      end

      it 'redirects to phone confirmation' do
        get :show

        expect(response).to redirect_to idv_otp_verification_path
      end
    end
  end

  describe '#confirm_current_password' do
    let(:applicant) do
      Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(phone_confirmed_at: Time.zone.now)
    end

    controller do
      before_action :confirm_current_password

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      stub_attempts_tracker
      routes.draw do
        post 'show' => 'idv/review#show'
      end
      allow(subject).to receive(:confirm_idv_steps_complete).and_return(true)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      allow(@irs_attempts_api_tracker).to receive(:track_event)
    end

    context 'user does not provide password' do
      it 'redirects to new' do
        post :show, params: { user: { password: '' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user provides wrong password' do
      before do
        post :show, params: { user: { password: 'wrong' } }
      end

      it 'redirects to new' do
        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_review_path
      end

      it 'tracks irs password entered event (idv_password_entered)' do
        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :idv_password_entered,
          success: false,
        )
      end
    end

    context 'user provides correct password' do
      it 'allows request to proceed' do
        post :show, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(response.body).to eq 'Hello'
      end
    end
  end

  describe '#new' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    end

    context 'user has completed all steps' do
      before do
        idv_session
      end

      it 'shows completed session' do
        get :new

        expect(response).to render_template :new
      end

      it 'displays a helpful flash message to the user' do
        get :new

        expect(flash.now[:success]).to eq(
          t(
            'idv.messages.review.info_verified_html',
            phone_message: ActionController::Base.helpers.content_tag(
              :strong,
              t('idv.messages.phone.phone_of_record'),
            ),
          ),
        )
      end
    end

    context 'user has not requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
        gpo_mail_service = instance_double(Idv::GpoMail)
        allow(Idv::GpoMail).to receive(:new).with(user).and_return(gpo_mail_service)
        allow(gpo_mail_service).to receive(:mail_spammed?).and_return(false)
      end

      it 'displays a success message' do
        get :new

        expect(flash.now[:error]).to be_nil
      end
    end

    context 'user has requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
        gpo_mail_service = instance_double(Idv::GpoMail)
        allow(Idv::GpoMail).to receive(:new).with(user).and_return(gpo_mail_service)
        allow(gpo_mail_service).to receive(:mail_spammed?).and_return(true)
      end

      it 'displays a helpful error message' do
        get :new

        expect(flash.now[:error]).to eq t('idv.errors.mail_limit_reached')
        expect(flash.now[:success]).to be_nil
      end
    end
  end

  describe '#create' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    end

    context 'user fails to supply correct password' do
      let(:applicant) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(phone_confirmed_at: Time.zone.now)
      end

      before do
        idv_session
      end

      it 'redirects to original path' do
        put :create, params: { user: { password: 'wrong' } }

        expect(response).to redirect_to idv_review_path

        expect(@analytics).to have_logged_event(
          'IdV: review complete',
          success: false,
          proofing_components: nil,
          deactivation_reason: nil,
        )
      end
    end

    context 'user has completed all steps' do
      before do
        idv_session
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)
      end

      it 'redirects to personal key path' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(@analytics).to have_logged_event(
          'IdV: review complete', success: true,
                                  proofing_components: nil,
                                  deactivation_reason: anything
        )
        expect(@analytics).to have_logged_event(
          'IdV: final resolution',
          hash_including(success: true),
        )
        expect(response).to redirect_to idv_personal_key_path
      end

      it 'redirects to confirmation path after user presses the back button' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(subject.user_session[:need_personal_key_confirmation]).to eq(true)

        allow_any_instance_of(User).to receive(:active_profile).and_return(true)
        get :new
        expect(response).to redirect_to idv_personal_key_path
      end

      it 'tracks irs password entered event (idv_password_entered)' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :idv_password_entered,
          success: true,
        )
      end

      it 'creates Profile with applicant attributes' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        profile = idv_session.profile
        pii = profile.decrypt_pii(ControllerHelper::VALID_PASSWORD)

        expect(pii.zipcode).to eq applicant[:zipcode]

        expect(pii.first_name).to eq applicant[:first_name]
      end

      context 'user picked phone confirmation' do
        before do
          idv_session.address_verification_mechanism = 'phone'
          idv_session.vendor_phone_confirmation = true
          idv_session.user_phone_confirmation = true
        end

        it 'activates profile' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

          profile = idv_session.profile
          profile.reload

          expect(profile).to be_active
        end

        it 'dispatches account verified alert' do
          expect(UserAlerts::AlertUserAboutAccountVerified).to receive(:call)

          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
        end

        it 'creates an `account_verified` event once per confirmation' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          disavowal_event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
            where.not(disavowal_token_fingerprint: nil).count
          expect(disavowal_event_count).to eq 1
        end

        context 'when the user goes through reproofing' do
          it 'does not log a reproofing event during initial proofing' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(@irs_attempts_api_tracker).not_to receive(:idv_reproof)
          end

          it 'logs a reproofing event upon reproofing' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            idv_session.profile.update(verified_at: nil)

            expect(@irs_attempts_api_tracker).to receive(:idv_reproof)

            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          end
        end

        context 'with in person profile' do
          let!(:enrollment) do
            create(:in_person_enrollment, :establishing, user: user, profile: nil)
          end
          let(:stub_usps_response) do
            stub_request_enroll
          end
          let(:applicant) do
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(
              same_address_as_id: true,
            )
          end

          before do
            stub_request_token
            stub_usps_response
            ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
            allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          end

          it 'redirects to personal key path' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(response).to redirect_to idv_personal_key_path
          end

          it 'creates a USPS enrollment' do
            proofer = UspsInPersonProofing::Proofer.new
            mock = double

            expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
            expect(mock).to receive(:request_enroll) do |applicant|
              expect(applicant.first_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
              expect(applicant.last_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
              expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
              expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
              expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
              expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
              expect(applicant.email).to eq('no-reply@login.gov')
              expect(applicant.unique_id).to be_a(String)

              proofer.request_enroll(applicant)
            end

            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          end

          it 'does not dispatch account verified alert' do
            expect(UserAlerts::AlertUserAboutAccountVerified).not_to receive(:call)

            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          end

          it 'creates an in-person enrollment record' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            enrollment.reload

            expect(enrollment.status).to eq('pending')
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_a(String)
            expect(enrollment.profile).to eq(user.profiles.last)
            expect(enrollment.profile.deactivation_reason).to eq('in_person_verification_pending')
          end

          it 'sends ready to verify email' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect_delivered_email_count(1)
            expect_delivered_email(
              to: [user.email_addresses.first.email],
              subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
            )
          end

          context 'when there is a 4xx error' do
            let(:stub_usps_response) do
              stub_request_enroll_bad_request_response
            end

            it 'logs the response message' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(@analytics).to have_logged_event(
                'USPS IPPaaS enrollment failed',
                context: 'authentication',
                enrollment_id: enrollment.id,
                exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
                exception_message: 'Sponsor for sponsorID 5 not found',
                original_exception_class: 'Faraday::BadRequestError',
                reason: 'Request exception',
              )
            end

            it 'leaves the enrollment in establishing' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(InPersonEnrollment.count).to be(1)
              enrollment = InPersonEnrollment.where(user_id: user.id).first
              expect(enrollment.status).to eq('establishing')
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end
          end

          context 'when there is 5xx error' do
            let(:stub_usps_response) do
              stub_request_enroll_internal_server_error_response
            end

            it 'logs the error message' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(@analytics).to have_logged_event(
                'USPS IPPaaS enrollment failed',
                context: 'authentication',
                enrollment_id: enrollment.id,
                exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
                exception_message: 'the server responded with status 500',
                original_exception_class: 'Faraday::ServerError',
                reason: 'Request exception',
              )
            end

            it 'leaves the enrollment in establishing' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(InPersonEnrollment.count).to be(1)
              enrollment = InPersonEnrollment.where(user_id: user.id).first
              expect(enrollment.status).to eq('establishing')
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end

            it 'allows the user to retry the request' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
              expect(flash[:error]).to eq t('idv.failure.exceptions.internal_error')
              expect(response).to redirect_to idv_review_path

              stub_request_enroll

              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(response).to redirect_to idv_personal_key_path

              enrollment.reload

              expect(enrollment.status).to eq('pending')
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_a(String)
              expect(enrollment.profile).to eq(user.profiles.last)
              expect(enrollment.profile.deactivation_reason).to eq('in_person_verification_pending')
            end
          end

          context 'when the USPS response is missing an enrollment code' do
            let(:stub_usps_response) do
              stub_request_enroll_invalid_response
            end

            it 'logs an error message' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(@analytics).to have_logged_event(
                'USPS IPPaaS enrollment failed',
                context: 'authentication',
                enrollment_id: enrollment.id,
                exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
                exception_message: 'Expected to receive an enrollment code',
                original_exception_class: 'StandardError',
                reason: 'Request exception',
              )
            end

            it 'leaves the enrollment in establishing' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(InPersonEnrollment.count).to be(1)
              enrollment = InPersonEnrollment.where(user_id: user.id).first
              expect(enrollment.status).to eq('establishing')
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end
          end

          context 'when user enters an address2 value' do
            let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(address2: '3b') }

            it 'provides address2 if the user entered it' do
              proofer = UspsInPersonProofing::Proofer.new
              mock = double

              expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
              expect(mock).to receive(:request_enroll) do |applicant|
                expect(applicant.address).
                  to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1] + ' 3b')
                proofer.request_enroll(applicant)
              end

              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
            end
          end
        end

        context 'with threatmetrix required but review status did not pass' do
          let(:applicant) do
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(same_address_as_id: true)
          end
          let(:stub_idv_session) do
            stub_user_with_applicant_data(user, applicant)
          end

          before(:each) do
            stub_request_token
            ProofingComponent.create(
              user: user,
              threatmetrix: true,
              threatmetrix_review_status: 'review',
            )
            allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
          end

          it 'creates a disabled profile' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(user.profiles.last.deactivation_reason).to eq('threatmetrix_review_pending')
          end

          it 'logs events' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
            expect(@analytics).to have_logged_event(
              'IdV: review complete', success: true,
                                      proofing_components: nil,
                                      deactivation_reason: 'threatmetrix_review_pending'
            )
            expect(@analytics).to have_logged_event(
              'IdV: final resolution', success: true,
                                       proofing_components: nil,
                                       deactivation_reason: 'threatmetrix_review_pending'
            )
          end
        end
      end

      context 'user picked GPO confirmation' do
        before do
          idv_session.address_verification_mechanism = 'gpo'
        end

        it 'leaves profile deactivated' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

          profile = idv_session.profile
          profile.reload

          expect(profile).to_not be_active
        end
      end
    end
  end
end
