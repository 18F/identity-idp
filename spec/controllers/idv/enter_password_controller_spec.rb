require 'rails_helper'

RSpec.describe Idv::EnterPasswordController do
  include UspsIppHelper

  let(:user) do
    create(
      :user,
      :fully_registered,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'old_email@example.com',
    )
  end
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:use_gpo) { false }
  let(:idv_session) do
    subject.idv_session
  end

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_analytics
    stub_sign_in(user)
    stub_attempts_tracker
    allow(@irs_attempts_api_tracker).to receive(:track_event)
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT
    subject.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:ssn]
    subject.idv_session.resolution_successful = true
    subject.idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
    subject.idv_session.resolution_successful = true

    if use_gpo
      subject.idv_session.address_verification_mechanism = 'gpo'
      subject.idv_session.vendor_phone_confirmation = false
      subject.idv_session.user_phone_confirmation = false
    else
      subject.idv_session.address_verification_mechanism = 'phone'
      subject.idv_session.vendor_phone_confirmation = true
      subject.idv_session.user_phone_confirmation = true
    end

    subject.idv_session.applicant = applicant.with_indifferent_access
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::EnterPasswordController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_step_allowed,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#confirm_current_password' do
    controller do
      before_action :confirm_current_password

      def show
        render plain: 'Hello'
      end
    end

    before do
      routes.draw do
        post 'show' => 'idv/enter_password#show'
      end
    end

    context 'user does not provide password' do
      it 'redirects to new' do
        post :show, params: { user: { password: '' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_enter_password_path
      end
    end

    context 'user provides wrong password' do
      before do
        post :show, params: { user: { password: 'wrong' } }
      end

      it 'redirects to new' do
        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_enter_password_path
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
    context 'user has completed all steps' do
      it 'shows completed session' do
        get :new

        expect(response).to render_template :new
      end

      it 'sets the correct title and header' do
        get :new

        expect(assigns(:title)).to eq(t('titles.idv.enter_password'))
        expect(assigns(:heading)).to eq(t('idv.titles.session.enter_password', app_name: APP_NAME))
      end

      it 'uses the correct step indicator step' do
        indicator_step = subject.step_indicator_step

        expect(indicator_step).to eq(:secure_account)
      end

      context 'user is in gpo flow' do
        before do
          subject.idv_session.vendor_phone_confirmation = false
          subject.idv_session.address_verification_mechanism = 'gpo'
        end

        render_views

        it 'sets the correct title and header' do
          get :new

          expect(assigns(:title)).to eq(t('titles.idv.enter_password_letter'))
          expect(assigns(:heading)).to eq(
            t('idv.titles.session.enter_password_letter', app_name: APP_NAME),
          )
        end

        it 'shows password reminder banner' do
          get :new

          expect(response.body).to include(
            t('idv.messages.enter_password.by_mail_password_reminder_html'),
          )
        end

        it 'uses the correct step indicator step' do
          indicator_step = subject.step_indicator_step

          expect(indicator_step).to eq(:get_a_letter)
        end
      end

      context 'not in gpo flow' do
        render_views
        it 'does not show password reminder banner for non-gpo' do
          get :new

          expect(response.body).not_to include(
            t('idv.messages.enter_password.by_mail_password_reminder_html'),
          )
        end
      end

      context 'with in-person proofing profile' do
        let(:user) do
          create(
            :user,
            :with_pending_in_person_enrollment,
            password: ControllerHelper::VALID_PASSWORD,
            email: 'old_email@example.com',
          )
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        end

        context 'when no personal key in idv_session' do
          before do
            idv_session.personal_key = nil
          end
          it 'redirects to ready to verify' do
            get :new
            expect(response).to redirect_to(idv_in_person_ready_to_verify_url)
          end
        end

        context 'when personal key present in idv_session' do
          before do
            idv_session.personal_key = 'ABCD-1234'
          end

          context 'when personal key not acknowledged' do
            it 'redirects to personal key' do
              get :new
              expect(response).to redirect_to(idv_personal_key_url)
            end
          end

          context 'when personal key acknowledged' do
            before do
              idv_session.acknowledge_personal_key!
            end
            it 'redirects to ready to verify' do
              get :new
              expect(response).to redirect_to(idv_in_person_ready_to_verify_url)
            end
          end
        end
      end

      context 'after successful submission' do
        before do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
        end
        it 'redirects to personal key' do
          get :new
          expect(response).to redirect_to(idv_personal_key_url)
        end

        context 'but user is still in gpo flow' do
          let(:use_gpo) { true }

          it 'redirects to letter enqueued' do
            get :new
            expect(response).to redirect_to(idv_letter_enqueued_url)
          end
        end
      end

      it 'updates the doc auth log for the user for the encrypt view event' do
        unstub_analytics
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { get :new }.to(
          change { doc_auth_log.reload.encrypt_view_count }.from(0).to(1),
        )
      end
    end

    it 'redirects to phone step if the user has not completed it' do
      subject.idv_session.vendor_phone_confirmation = nil

      get :new

      expect(response).to redirect_to(idv_phone_url)
    end
  end

  describe '#create' do
    context 'user fails to supply correct password' do
      it 'redirects to original path' do
        put :create, params: { user: { password: 'wrong' } }

        expect(response).to redirect_to idv_enter_password_path

        expect(@analytics).to have_logged_event(
          :idv_enter_password_submitted,
          success: false,
          fraud_review_pending: false,
          fraud_rejection: false,
          gpo_verification_pending: false,
          in_person_verification_pending: false,
          proofing_components: nil,
          deactivation_reason: nil,
          **ab_test_args,
        )
      end
    end

    it 'redirects to personal key path' do
      put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

      expect(@analytics).to have_logged_event(
        :idv_enter_password_submitted,
        success: true,
        fraud_review_pending: false,
        fraud_rejection: false,
        gpo_verification_pending: false,
        in_person_verification_pending: false,
        proofing_components: nil,
        deactivation_reason: anything,
        **ab_test_args,
      )
      expect(@analytics).to have_logged_event(
        'IdV: final resolution',
        hash_including(success: true),
      )
      expect(response).to redirect_to idv_personal_key_path
    end

    it 'redirects to confirmation path after user presses the back button' do
      put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
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

      profile = subject.idv_session.profile
      pii = profile.decrypt_pii(ControllerHelper::VALID_PASSWORD)

      expect(pii.zipcode).to eq subject.idv_session.applicant[:zipcode]

      expect(pii.first_name).to eq subject.idv_session.applicant[:first_name]
    end

    context 'user picked phone confirmation' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        subject.idv_session.address_verification_mechanism = 'phone'
        subject.idv_session.vendor_phone_confirmation = true
        subject.idv_session.user_phone_confirmation = true
      end

      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)

        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
      end

      it 'activates profile' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        profile = subject.idv_session.profile
        profile.reload

        expect(profile).to be_active
      end

      it 'dispatches account verified alert' do
        expect(UserAlerts::AlertUserAboutAccountVerified).to receive(:call)

        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
      end

      it 'creates an `account_verified` event once per confirmation' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
        events_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
          where(disavowal_token_fingerprint: nil).count
        expect(events_count).to eq 1
      end

      context 'with in person profile' do
        let!(:enrollment) do
          create(:in_person_enrollment, :establishing, user: user, profile: nil)
        end

        before do
          stub_request_token
          stub_request_enroll
          subject.idv_session.applicant =
            Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE
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

          expect(enrollment.status).to eq(InPersonEnrollment::STATUS_PENDING)
          expect(enrollment.user_id).to eq(user.id)
          expect(enrollment.enrollment_code).to be_a(String)
          expect(enrollment.profile).to eq(user.profiles.last)
          expect(enrollment.profile.in_person_verification_pending?).to eq(true)
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
          before do
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
            expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end
        end

        context 'when there is 5xx error' do
          before do
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
            expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end

          it 'allows the user to retry the request' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
            expect(flash[:error]).to eq t('idv.failure.exceptions.internal_error')
            expect(response).to redirect_to idv_enter_password_path

            stub_request_enroll

            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(response).to redirect_to idv_personal_key_path

            enrollment.reload

            expect(enrollment.status).to eq(InPersonEnrollment::STATUS_PENDING)
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_a(String)
            expect(enrollment.profile).to eq(user.profiles.last)
            expect(enrollment.profile.in_person_verification_pending?).to eq(true)
          end
        end

        context 'when the USPS response is not a hash' do
          before do
            stub_request_enroll_non_hash_response
          end

          it 'logs an error message' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(@analytics).to have_logged_event(
              'USPS IPPaaS enrollment failed',
              context: 'authentication',
              enrollment_id: enrollment.id,
              exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
              exception_message: 'Expected a hash but got a NilClass',
              original_exception_class: 'StandardError',
              reason: 'Request exception',
            )
          end

          context 'when there is a 4xx error' do
            before do
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
              expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end
          end

          context 'when there is 5xx error' do
            before do
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
              expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end

            it 'does not leave a personal_key in idv session' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
              expect(idv_session.personal_key).not_to be_present
            end

            it 'allows the user to retry the request' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
              expect(flash[:error]).to eq t('idv.failure.exceptions.internal_error')
              expect(response).to redirect_to idv_enter_password_path

              stub_request_enroll

              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(response).to redirect_to idv_personal_key_path

              enrollment.reload

              expect(enrollment.status).to eq(InPersonEnrollment::STATUS_PENDING)
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_a(String)
              expect(enrollment.profile).to eq(user.profiles.last)
              expect(enrollment.profile.in_person_verification_pending?).to eq(true)
            end
          end

          context 'when the USPS response is not a hash' do
            before do
              stub_request_enroll_non_hash_response
            end

            it 'logs an error message' do
              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

              expect(@analytics).to have_logged_event(
                'USPS IPPaaS enrollment failed',
                context: 'authentication',
                enrollment_id: enrollment.id,
                exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
                exception_message: 'Expected a hash but got a NilClass',
                original_exception_class: 'StandardError',
                reason: 'Request exception',
              )
            end
          end

          context 'when the USPS response is missing an enrollment code' do
            before do
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
              expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
              expect(enrollment.user_id).to eq(user.id)
              expect(enrollment.enrollment_code).to be_nil
            end
          end

          context 'when user enters an address2 value' do
            let(:applicant) do
              Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE.merge(address2: '3b')
            end

            it 'does not include address2' do
              proofer = UspsInPersonProofing::Proofer.new
              mock = double
              expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
              expect(mock).to receive(:request_enroll) do |applicant|
                expect(applicant.address).
                  to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
                proofer.request_enroll(applicant)
              end

              put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
            end
          end
        end

        context 'when the USPS response is missing an enrollment code' do
          before do
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
            expect(enrollment.status).to eq(InPersonEnrollment::STATUS_ESTABLISHING)
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end
        end

        context 'when user enters an address2 value' do
          it 'does not include address2' do
            subject.idv_session.applicant =
              Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE.
                merge(address2: '3b')
            proofer = UspsInPersonProofing::Proofer.new
            mock = double
            expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
            expect(mock).to receive(:request_enroll) do |applicant|
              expect(applicant.address).
                to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
              proofer.request_enroll(applicant)
            end

            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          end
        end
      end

      context 'threatmetrix review status is set in profile' do
        %i[enabled disabled].each do |proofing_device_profiling_state|
          context "when proofing_device_profiling is #{proofing_device_profiling_state}" do
            [nil, 'pass', 'review'].each do |review_status|
              context "when review status is #{review_status.nil? ? 'nil' : review_status}" do
                let(:fraud_review_pending?) do
                  proofing_device_profiling_state == :enabled &&
                    !review_status.nil? && review_status != 'pass'
                end
                let(:review_status) { review_status }
                let(:proofing_device_profiling_state) { proofing_device_profiling_state }

                before do
                  allow(IdentityConfig.store).to receive(:proofing_device_profiling).
                    and_return(proofing_device_profiling_state)
                  subject.idv_session.threatmetrix_review_status = review_status
                  stub_request_token
                end

                it 'creates a profile with fraud_review_pending defined' do
                  put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

                  expect(user.profiles.last.fraud_review_pending?).to eq(fraud_review_pending?)
                end

                it 'logs events' do
                  put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
                  expect(@analytics).to have_logged_event(
                    :idv_enter_password_submitted,
                    success: true,
                    fraud_review_pending: fraud_review_pending?,
                    fraud_rejection: false,
                    gpo_verification_pending: false,
                    in_person_verification_pending: false,
                    proofing_components: nil,
                    deactivation_reason: nil,
                    **ab_test_args,
                  )
                  expect(@analytics).to have_logged_event(
                    'IdV: final resolution',
                    success: true,
                    fraud_review_pending: fraud_review_pending?,
                    fraud_rejection: false,
                    gpo_verification_pending: false,
                    in_person_verification_pending: false,
                    proofing_components: nil,
                    deactivation_reason: nil,
                    **ab_test_args,
                  )
                end

                it 'updates the doc auth log for the user for the verified view event' do
                  unstub_analytics
                  doc_auth_log = DocAuthLog.create(user_id: user.id)

                  expect do
                    put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
                  end.to(
                    change { doc_auth_log.reload.verified_view_count }.from(0).to(1),
                  )
                end
              end
            end
          end
        end
      end
    end

    context 'user picked GPO confirmation' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
      end

      it 'leaves profile deactivated' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        profile = subject.idv_session.profile
        profile.reload

        expect(profile).to_not be_active
      end

      it 'sends an email about the gpo letter' do
        expect do
          put :create,
              params: {
                user: { password: ControllerHelper::VALID_PASSWORD },
              }
        end.to(change { ActionMailer::Base.deliveries.count }.by(1))
      end

      it 'logs USPS address letter enqueued event with phone_step_attempts', :freeze_time do
        RateLimiter.new(user: user, rate_limit_type: :proof_address).increment!
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter enqueued',
          resend: false,
          enqueued_at: Time.zone.now,
          phone_step_attempts: 1,
          first_letter_requested_at: subject.idv_session.profile.gpo_verification_pending_at,
          hours_since_first_letter: 0,
          proofing_components: nil,
          **ab_test_args,
        )
      end

      context 'when user is rate limited' do
        it 'logs USPS address letter enqueued event with phone_step_attempts', :freeze_time do
          rate_limit_type = :proof_address
          rate_limiter = RateLimiter.new(user: user, rate_limit_type: rate_limit_type)
          rate_limiter.increment_to_limited!
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

          expect(@analytics).to have_logged_event(
            'IdV: USPS address letter enqueued',
            resend: false,
            enqueued_at: Time.zone.now,
            phone_step_attempts: RateLimiter.max_attempts(rate_limit_type),
            first_letter_requested_at: subject.idv_session.profile.gpo_verification_pending_at,
            hours_since_first_letter: 0,
            proofing_components: nil,
            **ab_test_args,
          )
        end
      end

      it 'redirects to come back later page' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(response).to redirect_to idv_letter_enqueued_url
      end

      context 'applicant data is corrupted' do
        let(:applicant) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.dup.tap do |a|
            a.delete(:zipcode)
          end
        end

        before do
          expect do
            put :create,
                params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          end.to raise_error(GpoConfirmationMaker::InvalidEntryError)
        end

        it 'does not mint a GPO pending profile' do
          expect(user.reload.gpo_verification_pending_profile).to be_nil
        end

        it 'kills the idv session' do
          expect(subject.user_session[:idv]).to be_nil
        end
      end
    end
  end
end
