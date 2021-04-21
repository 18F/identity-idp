require 'rails_helper'

RSpec.describe ResolutionProofingJob, type: :job do
  let(:pii) do
    {
      dob: '01/01/1970',
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      address1: '123 Main St.',
      city: 'Milwaukee',
      state: 'WI',
      ssn: '444-55-8888',
      zipcode: Faker::Address.zip_code,
      state_id_jurisdiction: Faker::Address.state_abbr,
      state_id_number: '123456789',
      state_id_type: 'drivers_license',
      uuid: SecureRandom.hex,
    }
  end
  let(:encrypted_arguments) do
    Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,
    )
  end
  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:dob_year_only) { false }
  let(:should_proof_state_id) { true }

  let(:lexisnexis_transaction_id) { SecureRandom.uuid }
  let(:aamva_transaction_id) { SecureRandom.uuid }
  let(:resolution_proofer) do
    instance_double(LexisNexis::InstantVerify::Proofer, class: LexisNexis::InstantVerify::Proofer)
  end
  let(:state_id_proofer) { instance_double(Aamva::Proofer, class: Aamva::Proofer) }
  let(:trace_id) { SecureRandom.uuid }

  describe '.perform_later' do
    it 'stores results' do
      ResolutionProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        should_proof_state_id: should_proof_state_id,
        dob_year_only: dob_year_only,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
      )

      result = document_capture_session.load_proofing_result[:result]
      expect(result).to be_present
    end
  end

  describe '#perform' do
    let(:instance) { ResolutionProofingJob.new }

    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        should_proof_state_id: should_proof_state_id,
        dob_year_only: dob_year_only,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
      )
    end

    context 'webmock lexisnexis' do
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(body: lexisnexis_response.to_json)

        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)

        allow(AppConfig.env).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(AppConfig.env).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_username).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_password).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_base_url).
          and_return('https://lexisnexis.example.com/')
        allow(AppConfig.env).to receive(:lexisnexis_instant_verify_workflow).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_base_url).
          and_return('https://lexisnexis.example.com/')
        allow(AppConfig.env).to receive(:lexisnexis_instant_verify_workflow).and_return('aaa')

        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)

        allow(state_id_proofer).to receive(:proof).
          and_return(Proofer::Result.new(transaction_id: aamva_transaction_id))
      end

      let(:lexisnexis_response) do
        {
          'Status' => {
            'TransactionStatus' => 'passed',
            'ConversationId' => lexisnexis_transaction_id,
          },
        }
      end

      let(:dob_year_only) { false }

      it 'returns results' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        expect(result).to eq(
          exception: nil,
          errors: {},
          messages: [],
          success: true,
          timed_out: false,
          context: {
            stages: [
              {
                resolution: LexisNexis::InstantVerify::Proofer.vendor_name,
                transaction_id: lexisnexis_transaction_id,
              },
              {
                state_id: Aamva::Proofer.vendor_name,
                transaction_id: aamva_transaction_id,
              },
            ],
          },
          transaction_id: lexisnexis_transaction_id,
        )
      end

      context 'dob_year_only, failed response from lexisnexis' do
        let(:dob_year_only) { true }
        let(:should_proof_state_id) { true }
        let(:lexisnexis_response) do
          {
            'Status' => {
              'CoversationId' => lexisnexis_transaction_id,
              'Workflow' => 'foobar.baz',
              'TransactionStatus' => 'error',
              'TransactionReasonCode' => {
                'Code' => 'invalid_transaction_initiate',
              },
            },
            'Information' => {
              'InformationType' => 'error-details',
              'Code' => 'invalid_transaction_initiate',
              'Description' => 'Error: Invalid Transaction Initiate',
              'DetailDescription' => [
                { 'Text' => 'Date of Birth is not a valid date' },
              ],
            },
          }
        end

        it 'has a failed response' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result).to match(
            exception: kind_of(String),
            errors: {},
            messages: [],
            success: false,
            timed_out: false,
            context: {
              stages: [
                {
                  state_id: Aamva::Proofer.vendor_name,
                  transaction_id: aamva_transaction_id,
                },
                {
                  resolution: LexisNexis::InstantVerify::Proofer.vendor_name,
                  transaction_id: nil,
                },
              ],
            },
            transaction_id: nil,
          )
        end
      end
    end

    context 'stubbing vendors' do
      before do
        allow(instance).to receive(:resolution_proofer).and_return(resolution_proofer)
        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)
      end

      context 'with a successful response from the proofer' do
        before do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofer::Result.new)
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofer::Result.new)
        end

        it 'logs the trace_id and timing info' do
          expect(instance.logger).to receive(:info).with(hash_including(:timing, trace_id: trace_id))

          perform
        end
      end

      context 'does not call state id with an unsuccessful response from the proofer' do
        it 'posts back to the callback url' do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofer::Result.new(exception: 'error'))
          expect(state_id_proofer).not_to receive(:proof)

          perform
        end
      end

      context 'no state_id proof' do
        let(:should_proof_state_id) { false }

        it 'does not call state_id proof if resolution proof is successful' do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofer::Result.new)

          expect(state_id_proofer).not_to receive(:proof)
          perform
        end
      end

      context 'checking DOB year only' do
        let(:dob_year_only) { true }

        it 'only sends the birth year to LexisNexis (extra applicant attribute)' do
          expect(state_id_proofer).to receive(:proof).and_return(Proofer::Result.new)
          expect(resolution_proofer).to receive(:proof).
            with(hash_including(dob_year_only: true)).
            and_return(Proofer::Result.new)

          perform
        end

        it 'does not check LexisNexis when AAMVA proofing does not match' do
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofer::Result.new(exception: 'error'))
          expect(resolution_proofer).to_not receive(:proof)

          perform
        end

        it 'logs the correct context' do
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofer::Result.new(transaction_id: aamva_transaction_id))
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofer::Result.new(transaction_id: lexisnexis_transaction_id))

          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result.dig(:context, :stages)).to eq [
            { state_id: 'aamva:state_id', transaction_id: aamva_transaction_id },
            { resolution: 'lexisnexis:instant_verify', transaction_id: lexisnexis_transaction_id },
          ]

          expect(result.dig(:transaction_id)).to eq(lexisnexis_transaction_id)
        end
      end
    end
  end
end
