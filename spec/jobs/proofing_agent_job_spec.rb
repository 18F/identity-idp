# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentJob, type: :job do
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,
    )
  end
  let(:document_capture_session) do
    create(:document_capture_session, result_id: SecureRandom.hex)
  end
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:trace_id) { SecureRandom.uuid }
  let(:transaction_id) { SecureRandom.uuid }
  let(:webhook_url) { 'https://example.com/webhook' }
  let(:user) { document_capture_session.user }
  let(:service_provider) { create(:service_provider, app_id: 'fake-app-id') }
  let(:ipp_enrollment_in_progress) { false }
  let(:proofing_vendor) { IdentityConfig.store.idv_resolution_default_vendor }

  describe '#perform' do
    let(:instance) { ProofingAgentJob.new }

    before { ActiveJob::Base.queue_adapter = :test }

    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user.id,
        webhook_url: webhook_url,
        transaction_id: transaction_id,
        service_provider_issuer: service_provider.issuer,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        proofing_vendor: proofing_vendor,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
      )
    end

    context 'all proofing requests pass' do
      it 'stores a successful result' do
        perform

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:resolution][:success]).to be true
        expect(result[:resolution][:exception]).to be_nil
      end

      it 'enqueues a ProofingAgentWebhookJob with success: true' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          webhook_url: webhook_url,
          success: true,
          reason: nil,
          transaction_id: transaction_id,
        )
      end
    end

    context 'when resolution proofing fails' do
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(zipcode: '00000') }

      it 'stores a failed result' do
        perform

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('profile_resolution_fail')
        expect(result[:resolution][:success]).to be false
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          webhook_url: webhook_url,
          success: false,
          reason: 'profile_resolution_fail',
          transaction_id: transaction_id,
        )
      end
    end

    context 'when the AAMVA check passes' do
      it 'stores a successful result with aamva data' do
        perform

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:aamva][:success]).to be true
        expect(result[:aamva][:vendor_name]).to eq('StateIdMock')
      end
    end

    context 'when the AAMVA check fails' do
      let(:pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(state_id_number: '00000000')
      end

      it 'stores a failed result' do
        perform

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('id_fail')
        expect(result[:aamva][:success]).to be false
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          webhook_url: webhook_url,
          success: false,
          reason: 'id_fail',
          transaction_id: transaction_id,
        )
      end
    end

    context 'when the MRZ check passes' do
      let(:pii) { Idp::Constants::MOCK_IDV_PROOFING_PASSPORT_APPLICANT }

      it 'stores a successful result with mrz data' do
        perform

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be true
        expect(result[:reason]).to be_nil
        expect(result[:mrz][:success]).to be true
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

        result = document_capture_session.load_proofing_result[:result]
        expect(result[:success]).to be false
        expect(result[:reason]).to eq('passport_fail')
        expect(result[:mrz][:success]).to be false
      end

      it 'enqueues a ProofingAgentWebhookJob with success: false' do
        expect { perform }.to have_enqueued_job(ProofingAgentWebhookJob).with(
          webhook_url: webhook_url,
          success: false,
          reason: 'passport_fail',
          transaction_id: transaction_id,
        )
      end
    end

    context 'a stale job' do
      it 'bails and does not do any proofing' do
        instance.enqueued_at = 10.minutes.ago

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end
  end
end
