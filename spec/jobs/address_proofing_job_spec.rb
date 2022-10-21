require 'rails_helper'

RSpec.describe AddressProofingJob, type: :job do
  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: applicant_pii }.to_json,
    )
  end
  let(:user_id) { SecureRandom.random_number(1000) }
  let(:service_provider) { create(:service_provider) }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: Faker::PhoneNumber.cell_phone,
    }
  end
  let(:trace_id) { SecureRandom.hex }

  describe '.perform_later' do
    it 'stores results' do
      AddressProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user_id,
        issuer: service_provider.issuer,
      )

      result = document_capture_session.load_proofing_result[:result]
      expect(result).to be_present
    end
  end

  describe '#perform' do
    let(:conversation_id) { SecureRandom.hex }

    let(:instance) { AddressProofingJob.new }
    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user_id,
        issuer: service_provider.issuer,
      )
    end

    context 'webmock vendor' do
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(
          body: {
            Status: {
              ConversationId: conversation_id,
              TransactionStatus: 'passed',
            },
          }.to_json,
        )

        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
        allow(IdentityConfig.store).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(IdentityConfig.store).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_username).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_password).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
        allow(IdentityConfig.store).to receive(:lexisnexis_phone_finder_workflow).and_return('aaa')
      end

      it 'runs' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        expect(result[:exception]).to be_nil
        expect(result[:errors]).to eq({})
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false
        expect(result[:vendor_name]).to eq('lexisnexis:phone_finder')
      end

      it 'adds cost data' do
        expect { perform }.
          to(change { SpCost.count }.by(1).and(change { ProofingCost.count }.by(1)))

        sp_cost = SpCost.last
        expect(sp_cost.issuer).to eq(service_provider.issuer)
        expect(sp_cost.transaction_id).to eq(conversation_id)

        proofing_cost = ProofingCost.last
        expect(proofing_cost.user_id).to eq(user_id)
      end
    end

    context 'mock proofer' do
      context 'with an unsuccessful response from the proofer' do
        let(:applicant_pii) do
          super().merge(
            phone: Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
          )
        end

        it 'returns a result' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:success]).to eq(false)
        end
      end
    end

    context 'a stale job' do
      before { instance.enqueued_at = 10.minutes.ago }

      it 'bails and does not do any proofing' do
        expect(DocAuthRouter).to_not receive(:address_proofer)

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end
  end
end
