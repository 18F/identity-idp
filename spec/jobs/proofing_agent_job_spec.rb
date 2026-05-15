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
    create(:document_capture_session, result_id:, issuer:)
  end
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:trace_id) { SecureRandom.uuid }
  let(:transaction_id) { document_capture_session.uuid }
  let(:user) { document_capture_session.user }
  # let(:service_provider) { create(:service_provider, app_id: 'fake-app-id') }
  let(:webhook_url) { 'https://example.test/webhook' }
  let(:webhook_secret) { 'webhook-secret' }
  let(:webhook_status) { 200 }
  let(:idv_proofing_agent_config) do
    [
      {
        issuer:,
        webhook: {
          url: webhook_url,
          secret: webhook_secret,
        },
      }.with_indifferent_access,
    ]
  end

  describe '#perform' do
    let(:instance) { ProofingAgentJob.new }

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
        )
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
          )
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
        )
      end
    end

    context 'when the AAMVA check passes' do
      before do
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
        )
      end
    end

    context 'when the MRZ check passes' do
      let(:pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT }

      it 'stores a successful result with mrz data' do
        perform

        result = document_capture_session.reload.load_agent_proofed_user
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:mrz_status]).to eq 'pass'
        expect(result[:source_check_vendor]).to eq('PassportMock')
      end
    end

    context 'when the MRZ check fails' do
      let(:pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT }

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
      stub_request(:post, webhook_url).with { |req|
        body = JSON.parse(req.body)
        expect(body['success']).to be_in([true, false])
        if body['success']
          expect(body['reason']).to be_nil
        else
          expect(body['reason']).to be_present
        end
        expect(body['transaction_id']).to eq(transaction_id)
        expect(req.headers['X-Correlation-Id']).to eq(correlation_id)
        if webhook_secret.present?
          expect(req.headers['Authorization']).to eq("Bearer #{webhook_secret}")
        else
          expect(req.headers).not_to have_key('Authorization')
        end
      }.to_return(status: webhook_status)
    end
  end
end
