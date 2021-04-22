require 'rails_helper'
require 'proofing/address_mock_client'

RSpec.describe AddressProofingJob, type: :job do
  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:encrypted_arguments) do
    Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { applicant_pii: applicant_pii }.to_json,
    )
  end
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
        allow(AppConfig.env).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(AppConfig.env).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_username).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_password).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
        allow(AppConfig.env).to receive(:lexisnexis_phone_finder_workflow).and_return('aaa')
      end

      it 'runs' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        expect(result).to eq(
          exception: nil,
          errors: {},
          messages: [],
          success: true,
          timed_out: false,
          transaction_id: conversation_id,
          context: { stages: [
            { address: 'lexisnexis:phone_finder' },
          ] },
        )
      end
    end

    context 'mock proofer' do
      context 'with an unsuccessful response from the proofer' do
        let(:applicant_pii) do
          super().merge(
            phone: Proofing::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
          )
        end

        it 'returns a result' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:success]).to eq(false)
        end
      end
    end
  end
end
