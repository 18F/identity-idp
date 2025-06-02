require 'rails_helper'

RSpec.describe Idv::VerifyInfoController do
  include FlowPolicyHelper

  let(:user) { create(:user) }

  let(:analytics_hash) do
    {
      analytics_id: 'Doc Auth',
      flow_path: 'standard',
      step: 'verify',
    }
  end

  before do
    stub_sign_in(user)
    stub_up_to(:ssn, idv_session: subject.idv_session)
    stub_analytics
    stub_attempts_tracker
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::VerifyInfoController.step_info).to be_valid
    end

    describe '#undo_step' do
      let(:idv_session) do
        Idv::Session.new(
          user_session: {},
          current_user: user,
          service_provider: nil,
        ).tap do |idv_session|
          idv_session.address_edited = false
          idv_session.applicant = { first_name: 'Joe' }
          idv_session.residential_resolution_vendor = 'ResidentialResolutionVendor'
          idv_session.resolution_successful = true
          idv_session.resolution_vendor = 'ResolutionVendor'
          idv_session.source_check_vendor = 'aamva'
          idv_session.threatmetrix_review_status = 'pass'
          idv_session.verify_info_step_document_capture_session_uuid = 'abcd-1234'
        end
      end

      it 'resets relevant fields on idv_session to nil' do
        described_class.step_info.undo_step.call(idv_session:, user:)
        aggregate_failures do
          expect(idv_session.address_edited).to be(nil)
          expect(idv_session.applicant).to be(nil)
          expect(idv_session.residential_resolution_vendor).to be(nil)
          expect(idv_session.resolution_successful).to be(nil)
          expect(idv_session.resolution_vendor).to be(nil)
          expect(idv_session.source_check_vendor).to be(nil)
          expect(idv_session.threatmetrix_review_status).to be(nil)
          expect(idv_session.verify_info_step_document_capture_session_uuid).to be(nil)
        end
      end
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify visited',
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          step: 'verify',
        },
      )
    end

    it 'updates DocAuthLog verify_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.verify_view_count }.from(0).to(1),
      )
    end

    context 'address line 2' do
      render_views

      it 'With address2 in PII, shows address line 2 input' do
        subject.idv_session.pii_from_doc = subject.idv_session.pii_from_doc.with(address2: 'APT 3E')
        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end

      it 'No address2 in PII, still shows address line 2 input' do
        subject.idv_session.pii_from_doc = subject.idv_session.pii_from_doc.with(address2: nil)

        get :show

        expect(response.body).to have_content(t('idv.form.address2'))
      end
    end

    context 'when the user has already verified their info' do
      it 'renders show' do
        stub_up_to(:verify_info, idv_session: subject.idv_session)

        get :show

        expect(response).to render_template :show
      end
    end

    it 'redirects to ssn controller when ssn info is missing' do
      subject.idv_session.ssn = nil

      get :show

      expect(response).to redirect_to(idv_ssn_url)
    end

    context 'when the user is ssn rate limited' do
      before do
        RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          rate_limit_type: :proof_ssn,
        ).increment_to_limited!
      end

      it 'redirects to ssn failure url' do
        expect(@attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :proof_ssn,
        )
        get :show

        expect(response).to redirect_to idv_session_errors_ssn_failure_url

        expect(@analytics).to have_logged_event('Rate Limit Reached', limiter_type: :proof_ssn)
      end
    end

    context 'when the user is proofing rate limited' do
      before do
        RateLimiter.new(
          user: subject.current_user,
          rate_limit_type: :idv_resolution,
        ).increment_to_limited!
      end

      it 'redirects to rate limited url' do
        expect(@attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :idv_resolution,
        )
        get :show

        expect(response).to redirect_to idv_session_errors_failure_url

        expect(@analytics).to have_logged_event('Rate Limit Reached', limiter_type: :idv_resolution)
      end
    end

    context 'when proofing_device_profiling is enabled' do
      let(:threatmetrix_client_id) { 'threatmetrix_client' }
      let(:review_status) { 'pass' }
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
      let(:success) { true }

      let(:idv_result) do
        {
          context: {
            device_profiling_adjudication_reason: 'device_profiling_result',
            resolution_adjudication_reason: 'pass_resolution_and_state_id',
            stages: {
              threatmetrix: {
                success:,
                client: threatmetrix_client_id,
                transaction_id: 1,
                review_status: review_status,
                response_body: {
                  client: threatmetrix_client_id,
                  tmx_summary_reason_code: ['Identity_Negative_History'],
                },
              },
            },
          },
          errors: {},
          exception: nil,
          success: true,
          threatmetrix_review_status: review_status,
        }
      end

      let(:document_capture_session) do
        document_capture_session = DocumentCaptureSession.create!(user: user)
        document_capture_session.create_proofing_session
        document_capture_session.store_proofing_result(idv_result)
        document_capture_session
      end

      before do
        controller
          .idv_session
          .verify_info_step_document_capture_session_uuid = document_capture_session.uuid
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      end

      context 'when idv_session is missing threatmetrix_session_id' do
        before do
          controller.idv_session.threatmetrix_session_id = nil
        end

        it 'redirects back to the SSN step' do
          get :show
          expect(response).to redirect_to(idv_ssn_url)
        end

        it 'logs an idv_verify_info_missing_threatmetrix_session_id event' do
          get :show
          expect(@analytics).to have_logged_event(
            :idv_verify_info_missing_threatmetrix_session_id,
          )
        end

        context 'when ssn is not present in idv_session' do
          before do
            controller.idv_session.ssn = nil
          end

          it 'does not log an idv_verify_info_missing_threatmetrix_session_id event' do
            get :show
            expect(@analytics).not_to have_logged_event(
              :idv_verify_info_missing_threatmetrix_session_id,
            )
          end
        end
      end

      context 'when threatmetrix response is Pass' do
        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('pass')
        end

        # we use the client name for some error tracking, so make sure
        # it gets through to the analytics event log.
        it 'logs the analytics event, including the client' do
          get :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    threatmetrix: hash_including(
                      client: threatmetrix_client_id,
                    ),
                  ),
                ),
              ),
            ),
          )
          expect(@analytics).to have_logged_event(
            :idv_threatmetrix_response_body,
            response_body: hash_including(
              client: threatmetrix_client_id,
            ),
          )
        end

        it 'tracks the attempts events' do
          expect(@attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: true,
            failure_reason: nil,
          )
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: true,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: nil,
          )

          get :show
        end
      end

      context 'when threatmetrix response is No Result' do
        let(:review_status) { nil }
        let(:success) { false }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to be_nil
        end

        it 'tracks a failed tmx fraud check' do
          expect(@attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: { tmx_summary_reason_code: ['Identity_Negative_History'] },
          )

          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: true,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              failed_stages: [:threatmetrix],
              device_profiling_adjudication_reason: ['device_profiling_result'],
              resolution_adjudication_reason: ['pass_resolution_and_state_id'],
            },
          )

          get :show
        end
      end

      context 'when there is a threatmetrix exception' do
        let(:review_status) { nil }

        let(:idv_result) do
          {
            context: {
              device_profiling_adjudication_reason: 'device_profiling_exception',
              resolution_adjudication_reason: 'pass_resolution_and_state_id',
              errors: {},
              stages: {
                threatmetrix: {
                  client: nil,
                  errors: {},
                  exception: "Unexpected ThreatMetrix review_status value: #{review_status}",
                  response_body: nil,
                  review_status:,
                  success: false,
                  transaction_id: nil,
                },
              },
            },
            success: false,
          }
        end

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to be_nil
        end

        it 'redirects to warning_url' do
          get :show

          expect(response).to redirect_to idv_session_errors_warning_url

          expect(@analytics).to have_logged_event(
            'IdV: doc auth warning visited',
            step_name: 'verify_info',
            remaining_submit_attempts: kind_of(Integer),
          )
        end

        it 'logs the analytics event with the device profiling exception' do
          get :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              success: false,
              proofing_results: hash_including(
                context: hash_including(
                  device_profiling_adjudication_reason: 'device_profiling_exception',
                  stages: hash_including(
                    threatmetrix: hash_including(
                      exception: match(/\S+/),
                    ),
                  ),
                ),
              ),
            ),
          )
        end

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: false,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              failed_stages: [:threatmetrix],
              resolution_adjudication_reason: ['pass_resolution_and_state_id'],
              device_profiling_adjudication_reason: ['device_profiling_exception'],
            },
          )
          get :show
        end

        it 'tracks a failed tmx fraud check' do
          stub_attempts_tracker
          expect(@attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: {
              tmx_summary_reason_code: ['ThreatMetrix review has failed for unknown reasons'],
            },
          )

          get :show
        end
      end

      context 'when threatmetrix response is Reject' do
        let(:review_status) { 'reject' }
        let(:success) { false }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('reject')
        end

        it 'tracks a failed tmx fraud check' do
          expect(@attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success:,
            failure_reason: {
              tmx_summary_reason_code: ['Identity_Negative_History'],
            },
          )

          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: true,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              failed_stages: [:threatmetrix],
              device_profiling_adjudication_reason: ['device_profiling_result'],
              resolution_adjudication_reason: ['pass_resolution_and_state_id'],
            },
          )

          get :show
        end
      end

      context 'when threatmetrix response is Review' do
        let(:review_status) { 'review' }

        it 'sets the review status in the idv session' do
          get :show
          expect(controller.idv_session.threatmetrix_review_status).to eq('review')
        end

        it 'tracks a failed tmx fraud check' do
          stub_attempts_tracker
          expect(@attempts_api_tracker).to receive(:idv_tmx_fraud_check).with(
            success: false,
            failure_reason: {
              tmx_summary_reason_code: ['Identity_Negative_History'],
            },
          )

          get :show
        end
      end
    end

    context 'when proofing_device_profiling is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
      end

      context 'when idv_session is missing threatmetrix_session_id' do
        before do
          controller.idv_session.threatmetrix_session_id = nil
          get :show
        end

        it 'does not redirect back to the SSN step' do
          expect(response).not_to redirect_to(idv_ssn_url)
        end

        it 'does not track a threatmetrix check' do
          stub_attempts_tracker

          expect(@attempts_api_tracker).not_to receive(:idv_tmx_fraud_check)

          get :show
        end
      end
    end

    context 'when the user has updated their SSN' do
      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(success: true),
          phone_finder_result: Proofing::AddressResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: 'test-phone-vendor',
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: true,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(success: true),
          same_address_as_id: true,
          should_proof_state_id: true,
          applicant_pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

        document_capture_session.load_proofing_result
      end

      it 'logs the edit distance between SSNs' do
        allow(controller).to receive(:load_async_state).and_return(async_state)
        controller.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn]
        controller.idv_session.previous_ssn = '900661256'

        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(
            previous_ssn_edit_distance: 2,
          ),
        )
      end
    end

    context 'for an aamva request' do
      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:success) { true }
      let(:errors) { {} }
      let(:exception) { nil }
      let(:vendor_name) { 'aamva_placeholder' }
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: success,
            errors: errors,
            exception: exception,
            vendor_name: vendor_name,
            transaction_id: 'abc123',
            verified_attributes: [],
          ),
          phone_finder_result: Proofing::AddressResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: 'test-phone-vendor',
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: true,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(success: true),
          same_address_as_id: true,
          should_proof_state_id: true,
          applicant_pii:,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

        document_capture_session.load_proofing_result
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      context 'when aamva processes the request normally' do
        it 'redirect to phone confirmation url' do
          put :show
          expect(response).to redirect_to idv_phone_url
        end

        it 'logs an event with analytics_id set' do
          put :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              {
                analytics_id: 'Doc Auth',
                flow_path: 'standard',
                step: 'verify',
              },
            ),
          )

          event = @analytics.events['IdV: doc auth verify proofing results'].first
          state_id = event.dig(:proofing_results, :context, :stages, :state_id)
          expect(state_id).to match(
            hash_including(
              id_doc_type: 'drivers_license',
              vendor_name: 'aamva_placeholder',
            ),
          )
        end

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: true,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: nil,
          )
          get :show
        end
      end

      context 'when aamva returns success: false but no exception' do
        let(:success) { false }

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: false,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              failed_stages: [:state_id],
              resolution_adjudication_reason: ['fail_state_id'],
              device_profiling_adjudication_reason: ['device_profiling_result_pass'],
            },
          )
          get :show
        end

        it 'redirects to the warning URL' do
          put :show
          expect(response).to redirect_to(idv_session_errors_warning_url)
        end
      end

      context 'when aamva returns an exception' do
        let(:success) { false }
        let(:exception) { Proofing::Aamva::VerificationError.new('ExceptionId: 0001') }

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: false,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              failed_stages: [:state_id],
              resolution_adjudication_reason: ['fail_state_id'],
              device_profiling_adjudication_reason: ['device_profiling_result_pass'],
            },
          )
          get :show
        end

        it 'redirects user to warning' do
          put :show
          expect(response).to redirect_to idv_session_errors_state_id_warning_url
        end

        it 'logs an event' do
          put :show

          expect(@analytics).to have_logged_event(
            'IdV: doc auth warning visited',
            step_name: 'verify_info',
            remaining_submit_attempts: kind_of(Numeric),
          )
        end
      end
    end

    context 'when instant verify address proofing results in an exception' do
      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end
      let(:success) { false }
      let(:errors) { {} }
      let(:exception) { nil }
      let(:error_attributes) { nil }
      let(:vendor_name) { 'instantverify_placeholder' }
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(success: true),
          phone_finder_result: Proofing::AddressResult.new(
            success: success,
            errors: {},
            exception: exception,
            vendor_name: 'instant_verify_test',
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: false,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(
            success: success,
            errors: {},
            exception: 'fake exception',
            vendor_name: vendor_name,
            attributes_requiring_additional_verification: error_attributes,
          ),
          same_address_as_id: nil,
          should_proof_state_id: true,
          applicant_pii:,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

        document_capture_session.load_proofing_result
      end
      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      context 'address is the only exception' do
        let(:error_attributes) { ['address'] }

        it 'redirects user to address warning' do
          put :show
          expect(response).to redirect_to idv_session_errors_address_warning_url
        end

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: false,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              attributes_requiring_additional_verification: ['address'],
              failed_stages: [:resolution, :phone_precheck],
              resolution_adjudication_reason: ['fail_resolution_without_state_id_coverage'],
              device_profiling_adjudication_reason: ['device_profiling_result_pass'],
            },
          )
          get :show
        end

        it 'logs an event' do
          get :show

          expect(@analytics).to have_logged_event(
            :idv_doc_auth_address_warning_visited,
            step_name: 'verify_info',
            remaining_submit_attempts: kind_of(Numeric),
          )
        end
      end

      context 'there are more instant verify exceptions' do
        let(:error_attributes) { ['address', 'dob', 'ssn'] }

        it 'tracks the event for the attempts api' do
          expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
            success: false,
            document_state: applicant_pii[:state],
            document_number: applicant_pii[:state_id_number],
            document_issued: applicant_pii[:state_id_issued],
            document_expiration: applicant_pii[:state_id_expiration],
            first_name: applicant_pii[:first_name],
            last_name: applicant_pii[:last_name],
            date_of_birth: applicant_pii[:dob],
            address1: applicant_pii[:address1],
            address2: applicant_pii[:address2],
            ssn: applicant_pii[:ssn],
            failure_reason: {
              attributes_requiring_additional_verification: ['address', 'dob', 'ssn'],
              failed_stages: [:resolution, :phone_precheck],
              resolution_adjudication_reason: ['fail_resolution_without_state_id_coverage'],
              device_profiling_adjudication_reason: ['device_profiling_result_pass'],
            },
          )
          get :show
        end

        it 'redirects user to address warning' do
          put :show
          expect(response).to redirect_to idv_session_errors_exception_url
        end
      end
    end

    context 'when the resolution proofing job fails and there is no exception' do
      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: :aamva,
            transaction_id: 'abc123',
            verified_attributes: [],
          ),
          phone_finder_result: Proofing::AddressResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: 'test-phone-vendor',
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: true,
          residential_resolution_result: Proofing::Resolution::Result.new(success: true),
          resolution_result: Proofing::Resolution::Result.new(
            success: false,
            errors: {
              base: [
                "Verification failed with code: 'priority.scoring.model.verification.fail'",
              ],
            },
          ),
          same_address_as_id: true,
          should_proof_state_id: true,
          applicant_pii:,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

        document_capture_session.load_proofing_result
      end

      it 'tracks the attempts api event' do
        expect(@attempts_api_tracker).to receive(:idv_verification_submitted).with(
          success: false,
          document_state: applicant_pii[:state],
          document_number: applicant_pii[:state_id_number],
          document_issued: applicant_pii[:state_id_issued],
          document_expiration: applicant_pii[:state_id_expiration],
          first_name: applicant_pii[:first_name],
          last_name: applicant_pii[:last_name],
          date_of_birth: applicant_pii[:dob],
          address1: applicant_pii[:address1],
          address2: applicant_pii[:address2],
          ssn: applicant_pii[:ssn],
          failure_reason: {
            failed_stages: [:resolution],
            resolution_adjudication_reason: ['fail_resolution_without_state_id_coverage'],
            device_profiling_adjudication_reason: ['device_profiling_result_pass'],
          },
        )
        get :show
      end

      it 'renders the warning page' do
        get :show

        expect(response).to redirect_to(idv_session_errors_warning_url)
      end

      it 'logs an event' do
        get :show

        expect(@analytics).to have_logged_event(
          'IdV: doc auth warning visited',
          step_name: 'verify_info',
          remaining_submit_attempts: kind_of(Numeric),
        )
      end
    end

    context 'when the resolution proofing job has not completed' do
      let(:async_state) do
        ProofingSessionAsyncResult.new(status: ProofingSessionAsyncResult::IN_PROGRESS)
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      it 'renders the wait template' do
        get :show

        expect(response).to render_template 'shared/wait'
        expect(@analytics).to have_logged_event(:idv_doc_auth_verify_polling_wait_visited)
      end
    end

    context 'when the resolution proofing job result is missing' do
      let(:async_state) do
        ProofingSessionAsyncResult.new(status: ProofingSessionAsyncResult::MISSING)
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      it 'renders a timeout error' do
        get :show

        expect(response).to render_template :show
        expect(controller.flash[:error]).to eq(I18n.t('idv.failure.timeout'))
        expect(@analytics).to have_logged_event('IdV: proofing resolution result missing')
      end
    end

    context 'when the resolution proofing job completed successfully' do
      let(:document_capture_session) do
        DocumentCaptureSession.create(user:)
      end

      let(:resolution_vendor_name) { 'ResolutionVendor' }

      let(:residential_resolution_vendor_name) { 'ResidentialResolutionVendor' }

      let(:async_state) do
        # Here we're trying to match the store to redis -> read from redis flow this data travels
        adjudicated_result = Proofing::Resolution::ResultAdjudicator.new(
          state_id_result: Proofing::StateIdResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: :aamva,
            transaction_id: 'abc123',
            verified_attributes: [],
          ),
          phone_finder_result: Proofing::AddressResult.new(
            success: true,
            errors: {},
            exception: nil,
            vendor_name: 'test-phone-vendor',
          ),
          device_profiling_result: Proofing::DdpResult.new(success: true),
          ipp_enrollment_in_progress: true,
          residential_resolution_result: Proofing::Resolution::Result.new(
            success: true,
            vendor_name: residential_resolution_vendor_name,
          ),
          resolution_result: Proofing::Resolution::Result.new(
            success: true,
            vendor_name: resolution_vendor_name,
          ),
          same_address_as_id: true,
          should_proof_state_id: true,
          applicant_pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN,
        ).adjudicated_result.to_h

        document_capture_session.create_proofing_session

        document_capture_session.store_proofing_result(adjudicated_result)

        document_capture_session.load_proofing_result
      end

      before do
        allow(controller).to receive(:load_async_state).and_return(async_state)
      end

      it 'sets resolution_vendor on idv_session' do
        get :show
        expect(controller.idv_session.resolution_vendor).to eql(resolution_vendor_name)
      end

      it 'sets residential_resolution_vendor on idv_session' do
        get :show
        expect(controller.idv_session.residential_resolution_vendor).to(
          eql(residential_resolution_vendor_name),
        )
      end
    end
  end

  describe '#update' do
    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end

    it 'logs the correct analytics event' do
      put :update

      expect(@analytics).to have_logged_event(
        'IdV: doc auth verify submitted',
        **analytics_hash,
      )
    end

    it 'redirects to the expected page' do
      put :update

      expect(response).to redirect_to idv_verify_info_url
    end

    context 'with an sp' do
      let(:sp) { create(:service_provider) }
      let(:acr_values) { Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF }
      let(:vtr) { nil }
      let(:sp_session) { { issuer: sp.issuer, vtr:, acr_values: } }

      before do
        allow(controller).to receive(:sp_session).and_return(sp_session)
      end

      it 'modifies PII as expected' do
        expect(Idv::Agent).to receive(:new).with(
          hash_including(
            ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
            consent_given_at: controller.idv_session.idv_consent_given_at,
            **Idp::Constants::MOCK_IDV_APPLICANT,
          ),
        ).and_call_original

        put :update
      end

      context 'with vtr values' do
        let(:acr_values) { nil }
        let(:vtr) { ['C1'] }

        it 'modifies PII as expected' do
          expect(Idv::Agent).to receive(:new).with(
            hash_including(
              ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
              consent_given_at: controller.idv_session.idv_consent_given_at,
              **Idp::Constants::MOCK_IDV_APPLICANT,
            ),
          ).and_call_original

          put :update
        end
      end
    end

    it 'updates DocAuthLog verify_submit_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { put :update }.to(
        change { doc_auth_log.reload.verify_submit_count }.from(0).to(1),
      )
    end

    context 'when the user is ssn rate limited' do
      before do
        RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          ),
          rate_limit_type: :proof_ssn,
        ).increment_to_limited!
      end

      it 'redirects to ssn failure url' do
        put :update

        expect(response).to redirect_to idv_session_errors_ssn_failure_url
      end
    end

    context 'when the user is proofing rate limited' do
      before do
        RateLimiter.new(
          user: subject.current_user,
          rate_limit_type: :idv_resolution,
        ).increment_to_limited!
      end

      it 'redirects to rate limited url' do
        put :update

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end
  end

  describe '#best_effort_phone' do
    it 'returns nil when there is no number available' do
      expect(subject.best_effort_phone).to eq(nil)
    end

    context 'when there is a hybrid handoff number' do
      before(:each) do
        allow(subject.idv_session).to receive(:phone_for_mobile_flow).and_return('202-555-1234')
      end

      it 'returns the phone number from hybrid handoff' do
        expect(subject.best_effort_phone[:phone]).to eq('202-555-1234')
      end

      it 'sets type to :hybrid_handoff' do
        expect(subject.best_effort_phone[:source]).to eq(:hybrid_handoff)
      end
    end

    context 'when there was an MFA phone number provided' do
      let(:user) { create(:user, :with_phone) }

      it 'returns the MFA phone number' do
        expect(subject.best_effort_phone[:phone]).to eq('+1 202-555-1212')
      end

      it 'sets the phone source to :mfa' do
        expect(subject.best_effort_phone[:source]).to eq(:mfa)
      end
    end
  end
end
