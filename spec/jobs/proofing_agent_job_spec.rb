# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentJob, type: :job do
  include ActiveJob::TestHelper

  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE }
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,
    )
  end
  let(:result_id) { SecureRandom.uuid }
  let(:issuer) { 'favorite-sp-issuer' }
  let(:document_capture_session) do
    create(:document_capture_session, result_id:, issuer:, requested_at: Time.zone.now)
  end
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:trace_id) { SecureRandom.uuid }
  let(:transaction_id) { document_capture_session.uuid }
  let(:user) { document_capture_session.user }
  let(:webhook_url) { 'https://example.test/webhook' }
  let(:webhook_secret) { 'webhook-secret' }
  let(:webhook_status) { 200 }
  let(:webhook_headers) { nil }
  let(:idv_proofing_agent_config) do
    [
      {
        issuer:,
        webhook: {
          url: webhook_url,
          secret: webhook_secret,
          headers: webhook_headers,
        },
      }.with_indifferent_access,
    ]
  end
  let(:service_provider) { create(:service_provider, app_id: 'fake-app-id') }
  let(:submit_attempts) { 1 }
  let(:remaining_attempts) { 2 }

  describe '#perform' do
    let(:instance) { ProofingAgentJob.new }
    let(:final_attempt) { false }

    before do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      ActiveJob::Base.queue_adapter.performed_jobs.clear
      allow(IdentityConfig.store).to receive(:idv_proofing_agent_config)
        .and_return(idv_proofing_agent_config)
      allow(Db::SpCost::AddSpCost).to receive(:call)
    end

    after do
      request_stub = stub_webhook_request
      perform_enqueued_jobs
      remove_request_stub(request_stub) if request_stub
    end

    subject(:perform) do
      instance.perform(
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        transaction_id: transaction_id,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
        final_attempt: final_attempt,
        submit_attempts: submit_attempts,
        remaining_attempts: remaining_attempts,
      )
    end

    context 'all proofing requests pass' do
      before do
        allow(IdentityConfig.store).to receive(:idv_phone_precheck_percent).and_return(100)
      end

      it 'enqueues a ProofingAgentWebhookJob with success: true' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          success: true,
          reason: nil,
          transaction_id: transaction_id,
          correlation_id: correlation_id,
          analytics_attributes: {
            agent_id: proofing_agent_id,
            location_id: proofing_location_id,
            correlation_id: correlation_id,
            transaction_id: transaction_id,
            proofing_components: {
              document_check: nil,
              source_check: 'StateIdMock',
              residential_resolution_check: 'ResidentialAddressNotRequired',
              resolution_check: 'ResolutionMock',
              address_check: 'AddressMock',
            },
          },
        )
      end

      context 'logging' do
        before do
          stub_analytics
          allow(Analytics).to receive(:new).and_return(@analytics)
        end
        it 'logs idv_doc_auth_verify_proofing_results event with proofing agent' do
          perform
          expect(@analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            address_edited: false,
            address_line2_present: false,
            analytics_id: 'Doc Auth',
            flow_path: 'Proofing Agent',
            last_name_spaced: false,
            opted_in_to_in_person_proofing: false,
            proofing_results:
            { success: true,
              errors: nil,
              exception: nil,
              timed_out: false,
              threatmetrix_review_status: 'reject',
              hybrid_mobile_threatmetrix_review_status: nil,
              phone_precheck_passed: true,
              context:
              { device_profiling_adjudication_reason:
                'device_profiling_result_review_required',
                hybrid_mobile_device_profiling_adjudication_reason:
                'hybrid_mobile_device_profiling_not_enabled',
                resolution_adjudication_reason: 'pass_resolution_and_state_id',
                stages:
                { resolution:
                  { success: true,
                    errors: {},
                    exception: nil,
                    timed_out: false,
                    transaction_id: Proofing::Mock::ResolutionMockClient::TRANSACTION_ID,
                    reference: Proofing::Mock::ResolutionMockClient::REFERENCE,
                    reason_codes: {},
                    can_pass_with_additional_verification: false,
                    attributes_requiring_additional_verification: [],
                    source_attribution: [],
                    vendor_name: 'ResolutionMock',
                    vendor_id: nil,
                    vendor_workflow: nil,
                    verified_attributes: nil },
                  residential_address:
                  { success: true,
                    errors: {},
                    exception: nil,
                    timed_out: false,
                    transaction_id: '',
                    reference: '',
                    reason_codes: {},
                    can_pass_with_additional_verification: false,
                    attributes_requiring_additional_verification: [],
                    source_attribution: [],
                    vendor_name: 'ResidentialAddressNotRequired',
                    vendor_id: nil,
                    vendor_workflow: nil,
                    verified_attributes: nil },
                  threatmetrix:
                  { client: 'tmx_session_id_missing',
                    success: false,
                    errors: {},
                    exception: nil,
                    timed_out: false,
                    transaction_id: nil,
                    review_status: 'reject',
                    account_lex_id: nil,
                    session_id: nil,
                    response_body: nil,
                    device_fingerprint: nil },
                  hybrid_mobile_threatmetrix: {},
                  phone_precheck:
                  { exception: nil,
                    errors: {},
                    success: true,
                    timed_out: false,
                    transaction_id: Proofing::Mock::AddressMockClient::TRANSACTION_ID,
                    reference: '',
                    vendor_name: 'AddressMock',
                    result: nil } } },
              biographical_info:
              { birth_year: 1938,
                state: 'MT',
                identity_doc_address_state: 'MT',
                state_id_jurisdiction: 'ND',
                state_id_number: '#############',
                same_address_as_id: 'true',
                phone:
                { area_code: '202',
                  country_code: 'US',
                  phone_fingerprint: an_instance_of(String) },
                state_id_verified_attributes: ['address', 'dob', 'state_id_number'] },
              ssn_is_unique: true },
            ssn_is_unique: true,
            step: 'Proofing Agent Job',
            success: true,
            proofing_agent:
            { agent_id: proofing_agent_id,
              location_id: proofing_location_id,
              correlation_id: correlation_id,
              transaction_id: transaction_id },
            proofing_components:
            { document_check: nil,
              source_check: 'StateIdMock',
              residential_resolution_check: 'ResidentialAddressNotRequired',
              resolution_check: 'ResolutionMock',
              address_check: 'AddressMock' },
          )
        end
      end

      context 'when the webhook URL is not configured' do
        let(:webhook_url) { nil }
        it 'stores a successful result' do
          expect(ProofingAgentWebhookJob).not_to receive(:perform_later)

          perform

          result = document_capture_session.reload.load_agent_proofed_user
          expect(result[:success]).to be true
          expect(result[:reason]).to be_nil
          expect(result[:resolution][:success]).to be true
          expect(result[:resolution][:exception]).to be_nil
        end
      end

      context 'when the webhook URL is configured without a secret' do
        let(:webhook_secret) { nil }
        it 'enqueues a ProofingAgentWebhookJob with success: true' do
          expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
            success: true,
            reason: nil,
            transaction_id: transaction_id,
            correlation_id: correlation_id,
            analytics_attributes: an_instance_of(Hash),
          )
        end
      end

      context 'when the webhook URL is configured with additional headers' do
        let(:webhook_headers) { { 'X-Test-Header' => 'test-value' } }
        it 'includes the additional headers in the webhook request' do
          expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
            success: true,
            reason: nil,
            transaction_id: transaction_id,
            correlation_id: correlation_id,
          )

          result = document_capture_session.reload.load_agent_proofed_user
          expect(result[:success]).to be true
          expect(result[:reason]).to be_nil
          expect(result[:resolution][:success]).to be true
          expect(result[:resolution][:exception]).to be_nil
        end
      end

      context 'when an error occurs while delivering the webhook' do
        before do
          allow(NewRelic::Agent).to receive(:notice_error)
          allow(Faraday).to receive(:new).with(hash_including(url: webhook_url))
            .and_raise(StandardError.new('webhook error'))
        end

        it 'notifies NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error).with(
            instance_of(StandardError),
            custom_params: {
              event: 'Failed to deliver proofing agent webhook',
              webhook_url:,
              transaction_id:,
            },
          )
          expect { perform }.not_to raise_error
        end
      end

      context 'when the webhook returns a non-success status' do
        let(:webhook_status) { 500 }

        it 'retries the webhook request' do
          expect { perform }.not_to raise_error
        end
      end
    end

    context 'when resolution proofing fails' do
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(zipcode: '00000') }

      let(:webhook_status) { 500 }
      it 'stores a failed result' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('profile_resolution_fail')
        expect(result[:resolution][:success]).to be false
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          success: false,
          reason: 'profile_resolution_fail',
          transaction_id: transaction_id,
          correlation_id: correlation_id,
          analytics_attributes: an_instance_of(Hash),
        )
      end
    end

    context 'when the AAMVA check passes' do
      before do
        stub_analytics
        allow(Analytics).to receive(:new).and_return(@analytics)
        allow(IdentityConfig.store).to receive(:idv_phone_precheck_percent).and_return(100)
      end

      it 'stores a successful result with aamva data' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:aamva_status]).to eq 'passed'
        expect(result[:source_check_vendor]).to eq('StateIdMock')
      end

      it 'logs phone confirmation vendor event with proofing agent' do
        perform
        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation vendor',
          success: true,
          errors: {},
          vendor: 'AddressMock',
          area_code: '202',
          country_code: 'US',
          new_phone_added: true,
          hybrid_handoff_phone_used: false,
          manual_review: false,
          proofing_agent: {
            agent_id: proofing_agent_id,
            location_id: proofing_location_id,
            correlation_id: correlation_id,
            transaction_id: transaction_id,
          },
          proofing_components: {
            document_check: nil,
            residential_resolution_check: 'ResidentialAddressNotRequired',
            resolution_check: 'ResolutionMock',
            address_check: 'AddressMock',
            source_check: 'StateIdMock',
          },
        )
      end

      it 'passes aamva_verified_attributes into resolution_result' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:pii][:aamva_verified_attributes]).to be_present
      end
    end

    context 'when the AAMVA check fails' do
      let(:pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(state_id_number: '00000000')
      end

      it 'stores a failed result' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('id_fail')
        expect(result[:aamva_status]).to eq 'failed'
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          success: false,
          reason: 'id_fail',
          transaction_id: transaction_id,
          correlation_id: correlation_id,
          analytics_attributes: an_instance_of(Hash),
        )
      end
    end

    context 'when the MRZ check passes' do
      let(:pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT.merge(phone: '12025551212').freeze }
      before do
        stub_analytics
        allow(Analytics).to receive(:new).and_return(@analytics)
      end

      it 'stores a successful result with mrz data' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:mrz_status]).to eq 'pass'
        expect(result[:source_check_vendor]).to eq('PassportMock')
      end

      it 'logs idv_dos_passport_verification event with proofing agent' do
        perform
        expect(@analytics).to have_logged_event(
          :idv_dos_passport_verification,
          success: true,
          submit_attempts: 1,
          remaining_submit_attempts: 2,
          document_type_requested: 'passport',
          correlation_id_sent: correlation_id,
          proofing_agent: {
            agent_id: proofing_agent_id,
            location_id: proofing_location_id,
            correlation_id: correlation_id,
            transaction_id: transaction_id,
          },
        )
      end
    end

    context 'when the MRZ check fails' do
      let(:pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT.merge(phone: '12025551212').freeze }

      before do
        failing_response = DocAuth::Response.new(
          success: false,
          errors: { passport: I18n.t('doc_auth.errors.general.fallback_field_level') },
        )
        allow(DocAuth::Mock::DosPassportApiClient).to receive(:new)
          .and_return(instance_double(DocAuth::Mock::DosPassportApiClient, fetch: failing_response))
      end

      it 'stores a failed result' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('passport_fail')
        expect(result[:mrz_status]).to eq 'failed'
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          success: false,
          reason: 'passport_fail',
          transaction_id: transaction_id,
          correlation_id: correlation_id,
          analytics_attributes: an_instance_of(Hash),
        )
      end
    end

    context 'a stale job' do
      it 'bails and does not do any proofing' do
        instance.enqueued_at = 10.minutes.ago

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end

    def stub_webhook_request
      return if webhook_url.blank?
      stub_request(:post, webhook_url).with do |req|
        body = JSON.parse(req.body)
        expect(body['success']).to be_in([true, false])
        if body['success'] == true
          expect(body['reason']).to be_nil
        elsif body['success'] == false
          expect(body['reason']).to be_present
        else
          raise "Unexpected success value: #{body['success']}"
        end
        expect(body['transaction_id']).to eq(transaction_id)
        expect(req.headers['X-Correlation-Id']).to eq(correlation_id)

        webhook_headers&.each do |key, value|
          expect(req.headers[key]).to eq(value)
        end

        if webhook_secret.present?
          expect(req.headers['Authorization']).to eq("Bearer #{webhook_secret}")
        else
          expect(req.headers).not_to have_key('Authorization')
        end
      end.to_return(status: webhook_status)
    end

    context 'failure email on final attempt' do
      let(:job_analytics) { FakeAnalytics.new }

      before do
        ActionMailer::Base.deliveries.clear
        allow(Analytics).to receive(:new).and_return(job_analytics)
      end

      context 'when final_attempt is true and proofing fails' do
        let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(zipcode: '00000') }
        let(:final_attempt) { true }

        it 'sends a failure email to the user' do
          expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
          expect(ActionMailer::Base.deliveries.last.to)
            .to eq([user.confirmed_email_addresses.first.email])
        end

        it 'logs the failure email analytics event' do
          perform

          expect(job_analytics).to have_logged_event(
            :idv_proofing_agent_failure_to_proof_email_sent,
            user_id: user.uuid,
            proofing_agent: {
              correlation_id: correlation_id,
              transaction_id: transaction_id,
              agent_id: proofing_agent_id,
              location_id: proofing_location_id,
            },
            reason: 'profile_resolution_fail',
          )
        end

        context 'when requested_at is nil' do
          before do
            document_capture_session.update!(requested_at: nil)
          end

          it 'sends a failure email to the user with a fallback timestamp' do
            expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
            expect(ActionMailer::Base.deliveries.last.to)
              .to eq([user.confirmed_email_addresses.first.email])
          end
        end
      end

      context 'when final_attempt is true and proofing succeeds' do
        let(:final_attempt) { true }

        before do
          allow(IdentityConfig.store).to receive(:idv_phone_precheck_percent).and_return(100)
        end

        it 'does not send a failure email' do
          expect { perform }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end

      context 'when final_attempt is false and proofing fails' do
        let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(zipcode: '00000') }

        it 'does not send a failure email' do
          expect { perform }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end
  end
end
