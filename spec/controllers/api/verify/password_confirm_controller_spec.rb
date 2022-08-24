require 'rails_helper'

describe Api::Verify::PasswordConfirmController do
  include PersonalKeyValidator
  include SamlAuthHelper
  include UspsIppHelper

  def stub_idv_session
    stub_sign_in(user)
  end

  let(:password) { 'iambatman' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }

  let(:profile) { subject.idv_session.profile }
  let(:key) { OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_private_key)) }
  let(:jwt_metadata) { { vendor_phone_confirmation: true, user_phone_confirmation: true } }
  let(:jwt) { JWT.encode({ pii: applicant, metadata: jwt_metadata }, key, 'RS256', sub: user.uuid) }

  before do
    stub_analytics
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['password_confirm'])
  end

  it 'extends behavior of base api class' do
    expect(subject).to be_kind_of Api::Verify::BaseController
  end

  describe '#create' do
    context 'when the user is not signed in and submits the password' do
      it 'does not create a profile or return a key' do
        post :create, params: { password: 'iambatman', user_bundle_token: jwt }
        parsed_body = JSON.parse(response.body, symbolize_names: true)

        expect(response.status).to eq 401
        expect(parsed_body).to eq(errors: { user: 'Unauthorized' })
      end
    end

    context 'when the user is signed in and submits the password' do
      before do
        stub_idv_session
      end

      it 'creates a profile and returns a key and completion url' do
        post :create, params: { password: password, user_bundle_token: jwt }
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).to include(
          'personal_key' => kind_of(String),
          'completion_url' => account_url,
        )
        expect(response.status).to eq 200
      end

      it 'does not create a profile and return a key when it has the wrong password' do
        post :create, params: { password: 'iamnotbatman', user_bundle_token: jwt }
        response_json = JSON.parse(response.body)
        expect(response_json['personal_key']).to be_nil
        expect(response_json['errors']['password']).to eq([I18n.t('idv.errors.incorrect_password')])
        expect(response.status).to eq 400
      end

      context 'with in-person profile' do
        let(:applicant) {
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(same_address_as_id: true)
        }
        let(:stub_idv_session) do
          stub_user_with_applicant_data(user, applicant)
        end
        let(:stub_usps_response) do
          stub_request_enroll
        end
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: nil) }

        before(:each) do
          stub_request_token
          stub_usps_response
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        end

        context 'when there is a 4xx error' do
          let(:stub_usps_response) do
            stub_request_enroll_bad_request_response
          end

          it 'logs the response message' do
            post :create, params: { password: password, user_bundle_token: jwt }

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
            post :create, params: { password: password, user_bundle_token: jwt }

            expect(InPersonEnrollment.count).to be(1)
            enrollment = InPersonEnrollment.where(user_id: user.id).first
            expect(enrollment.status).to eq('establishing')
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end
        end

        context 'when there is 5xx error' do
          let(:stub_usps_response) do
            stub_request_enroll_internal_failure_response
          end

          it 'logs the error message' do
            post :create, params: { password: password, user_bundle_token: jwt }

            expect(@analytics).to have_logged_event(
              'USPS IPPaaS enrollment failed',
              enrollment_id: enrollment.id,
              exception_class: 'UspsInPersonProofing::Exception::RequestEnrollException',
              exception_message: 'the server responded with status 500',
              original_exception_class: 'Faraday::ServerError',
              reason: 'Request exception',
            )
          end

          it 'leaves the enrollment in establishing' do
            post :create, params: { password: password, user_bundle_token: jwt }

            expect(InPersonEnrollment.count).to be(1)
            enrollment = InPersonEnrollment.where(user_id: user.id).first
            expect(enrollment.status).to eq('establishing')
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end

          it 'allows the user to retry the request' do
            post :create, params: { password: password, user_bundle_token: jwt }
            expect(response.status).to eq 400
            stub_request_enroll

            post :create, params: { password: password, user_bundle_token: jwt }

            parsed_body = JSON.parse(response.body)
            expect(parsed_body).to include(
              'personal_key' => kind_of(String),
              'completion_url' => idv_in_person_ready_to_verify_url,
            )
            expect(response.status).to eq 200

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
            post :create, params: { password: password, user_bundle_token: jwt }

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
            post :create, params: { password: password, user_bundle_token: jwt }

            expect(InPersonEnrollment.count).to be(1)
            enrollment = InPersonEnrollment.where(user_id: user.id).first
            expect(enrollment.status).to eq('establishing')
            expect(enrollment.user_id).to eq(user.id)
            expect(enrollment.enrollment_code).to be_nil
          end
        end

        it 'creates a profile and returns completion url' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(
            idv_in_person_ready_to_verify_url,
          )
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

          post :create, params: { password: password, user_bundle_token: jwt }
        end

        context 'when user enters an address2 value' do
          let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(address2: '3b') }

          it 'provides address2 if the user entered it' do
            proofer = UspsInPersonProofing::Proofer.new
            mock = double

            expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
            expect(mock).to receive(:request_enroll) do |applicant|
              expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1] + ' 3b')
              proofer.request_enroll(applicant)
            end

            post :create, params: { password: password, user_bundle_token: jwt }
          end
        end

        it 'creates an in-person enrollment record' do
          post :create, params: { password: password, user_bundle_token: jwt }

          enrollment.reload

          expect(enrollment.status).to eq('pending')
          expect(enrollment.user_id).to eq(user.id)
          expect(enrollment.enrollment_code).to be_a(String)
          expect(enrollment.profile).to eq(user.profiles.last)
          expect(enrollment.profile.deactivation_reason).to eq('in_person_verification_pending')
        end

        it 'sends ready to verify email' do
          mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
          user.email_addresses.each do |email_address|
            expect(UserMailer).to receive(:in_person_ready_to_verify).
              with(
                user,
                email_address,
                enrollment: instance_of(InPersonEnrollment),
                first_name: kind_of(String),
              ).
              and_return(mailer)
          end

          post :create, params: { password: password, user_bundle_token: jwt }
        end
      end

      context 'with associated sp session' do
        before do
          session[:sp] = { issuer: create(:service_provider).issuer }
        end

        it 'creates a profile and returns completion url' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(sign_up_completed_url)
        end
      end

      context 'with pending profile' do
        let(:jwt_metadata) do
          {
            vendor_phone_confirmation: false,
            user_phone_confirmation: false,
            address_verification_mechanism: 'gpo',
          }
        end

        it 'creates a profile and returns completion url' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(idv_come_back_later_url)
        end

        context 'with in person profile' do
          let(:applicant) {
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(same_address_as_id: true)
          }
          let(:stub_idv_session) do
            stub_user_with_applicant_data(user, applicant)
          end

          before do
            ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
            allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          end

          it 'creates a profile and returns completion url' do
            post :create, params: { password: password, user_bundle_token: jwt }

            expect(JSON.parse(response.body)['completion_url']).to eq(idv_come_back_later_url)
          end
        end
      end

      context 'with device profiling decisioning enabled' do
        before do
          ProofingComponent.create(user: user, threatmetrix: true, threatmetrix_review_status: nil)
          allow(IdentityConfig.store).
            to receive(:proofing_device_profiling_decisioning_enabled).
            and_return(true)
        end

        it 'redirects to come back later path when threatmetrix review status is nil' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(account_url)
        end

        it 'redirects to account path when device profiling passes' do
          ProofingComponent.find_by(user: user).update(threatmetrix_review_status: 'pass')
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(account_url)
        end

        it 'redirects to come back later path when device profiling fails' do
          ProofingComponent.find_by(user: user).update(threatmetrix_review_status: 'fail')
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(idv_come_back_later_url)
        end
      end

      context 'with gpo_code returned from form submission and reveal gpo feature enabled' do
        let(:gpo_code) { SecureRandom.hex }

        let(:form) do
          Api::ProfileCreationForm.new(
            password: password,
            jwt: jwt,
            user_session: {},
            service_provider: {},
          )
        end

        before do
          allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
          allow(subject).to receive(:form).and_return(form)
          allow(form).to receive(:gpo_code).and_return(gpo_code)
        end

        it 'sets code into the session' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(session[:last_gpo_confirmation_code]).to eq(gpo_code)
        end
      end
    end

    context 'when the idv api is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return([])
      end

      it 'responds with not found' do
        post :create, params: { password: password, user_bundle_token: jwt }, as: :json
        expect(response.status).to eq 404
        expect(JSON.parse(response.body)['error']).
          to eq "The page you were looking for doesn't exist"
      end
    end
  end
end
