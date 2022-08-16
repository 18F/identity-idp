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
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,
    )
  end
  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:dob_year_only) { false }
  let(:should_proof_state_id) { true }

  let(:lexisnexis_transaction_id) { SecureRandom.uuid }
  let(:lexisnexis_reference) { SecureRandom.uuid }
  let(:aamva_transaction_id) { SecureRandom.uuid }
  let(:resolution_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      class: Proofing::LexisNexis::InstantVerify::Proofer,
    )
  end
  let(:state_id_proofer) do
    instance_double(Proofing::Aamva::Proofer, class: Proofing::Aamva::Proofer)
  end
  let(:trace_id) { SecureRandom.uuid }
  let(:user) { build(:user, :signed_up) }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:threatmetrix_request_id) { 'ddp-mock-transaction-id-123' }

  describe '.perform_later' do
    it 'stores results' do
      ResolutionProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        should_proof_state_id: should_proof_state_id,
        dob_year_only: dob_year_only,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user.id,
        threatmetrix_session_id: threatmetrix_session_id,
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
        user_id: user.id,
        threatmetrix_session_id: threatmetrix_session_id,
      )
    end

    context 'webmock lexisnexis and threatmetrix' do
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(body: lexisnexis_response.to_json)
        stub_request(
          :post,
          'https://www.example.com/api/session-query',
        ).to_return(body: LexisNexisFixtures.ddp_success_response_json)

        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_enabled).
          and_return(true)

        allow(IdentityConfig.store).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(IdentityConfig.store).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_username).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_password).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_base_url).
          and_return('https://lexisnexis.example.com/')
        allow(IdentityConfig.store).to receive(:lexisnexis_instant_verify_workflow).
          and_return('aaa')

        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)

        allow(state_id_proofer).to receive(:proof).
          and_return(Proofing::Result.new(transaction_id: aamva_transaction_id))
      end

      let(:lexisnexis_response) do
        {
          'Status' => {
            'TransactionStatus' => 'passed',
            'ConversationId' => lexisnexis_transaction_id,
            'Reference' => lexisnexis_reference,
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
            dob_year_only: dob_year_only,
            should_proof_state_id: true,
            stages: {
              resolution: {
                client: Proofing::LexisNexis::InstantVerify::Proofer.vendor_name,
                errors: {},
                exception: nil,
                success: true,
                timed_out: false,
                transaction_id: lexisnexis_transaction_id,
                reference: lexisnexis_reference,
              },
              state_id: {
                client: Proofing::Aamva::Proofer.vendor_name,
                errors: {},
                exception: nil,
                success: true,
                timed_out: false,
                transaction_id: aamva_transaction_id,
              },
            },
          },
          transaction_id: lexisnexis_transaction_id,
          reference: lexisnexis_reference,
          threatmetrix_success: true,
          threatmetrix_request_id: threatmetrix_request_id,
        )
      end

      context 'dob_year_only, failed response from lexisnexis' do
        let(:dob_year_only) { true }
        let(:should_proof_state_id) { true }
        let(:lexisnexis_response) do
          {
            'Status' => {
              'ConversationId' => lexisnexis_transaction_id,
              'Reference' => lexisnexis_reference,
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
            exception: nil,
            errors: {
              base: [
                a_string_starting_with(
                  'Response error with code \'invalid_transaction_initiate\':',
                ),
              ],
            },
            messages: [],
            success: false,
            timed_out: false,
            context: {
              dob_year_only: dob_year_only,
              should_proof_state_id: true,
              stages: {
                state_id: {
                  client: Proofing::Aamva::Proofer.vendor_name,
                  errors: {},
                  exception: nil,
                  success: true,
                  timed_out: false,
                  transaction_id: aamva_transaction_id,
                },
                resolution: {
                  client: Proofing::LexisNexis::InstantVerify::Proofer.vendor_name,
                  errors: {
                    base: [
                      a_string_starting_with(
                        'Response error with code \'invalid_transaction_initiate\':',
                      ),
                    ],
                  },
                  exception: nil,
                  success: false,
                  timed_out: false,
                  transaction_id: lexisnexis_transaction_id,
                  reference: lexisnexis_reference,
                },
              },
            },
            transaction_id: lexisnexis_transaction_id,
            reference: lexisnexis_reference,
            threatmetrix_request_id: threatmetrix_request_id,
            threatmetrix_success: true,
          )
        end
      end
    end

    context 'stubbing vendors' do
      before do
        allow(instance).to receive(:resolution_proofer).and_return(resolution_proofer)
        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_enabled).
          and_return(true)
      end

      context 'with a successful response from the proofer' do
        before do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofing::Result.new)
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofing::Result.new)
        end

        it 'logs the trace_id and timing info for ProofResolution and the Threatmetrix info' do
          expect(instance).to receive(:logger_info_hash).ordered.with(
            hash_including(
              name: 'ThreatMetrix',
              user_id: nil,
              threatmetrix_request_id: Proofing::Mock::DdpMockClient::TRANSACTION_ID,
              threatmetrix_success: true,
            ),
          )

          expect(instance).to receive(:logger_info_hash).ordered.with(
            hash_including(
              :timing,
              name: 'ProofResolution',
              trace_id: trace_id,
            ),
          )

          perform
        end
      end

      context 'does not call state id with an unsuccessful response from the proofer' do
        it 'posts back to the callback url' do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofing::Result.new(exception: 'error'))
          expect(state_id_proofer).not_to receive(:proof)

          perform
        end
      end

      context 'no state_id proof' do
        let(:should_proof_state_id) { false }

        it 'does not call state_id proof if resolution proof is successful' do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofing::Result.new)

          expect(state_id_proofer).not_to receive(:proof)
          perform
        end
      end

      context 'checking DOB year only' do
        let(:dob_year_only) { true }

        it 'only sends the birth year to LexisNexis (extra applicant attribute)' do
          expect(state_id_proofer).to receive(:proof).and_return(Proofing::Result.new)
          expect(resolution_proofer).to receive(:proof).
            with(hash_including(dob_year_only: true)).
            and_return(Proofing::Result.new)

          perform
        end

        it 'does not check LexisNexis when AAMVA proofing does not match' do
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofing::Result.new(exception: 'error'))
          expect(resolution_proofer).to_not receive(:proof)

          perform
        end

        it 'logs the correct context' do
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofing::Result.new(transaction_id: aamva_transaction_id))
          expect(resolution_proofer).to receive(:proof).and_return(
            Proofing::Result.new(
              transaction_id: lexisnexis_transaction_id,
              reference: lexisnexis_reference,
            ),
          )

          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:context]).to eq(
            {
              dob_year_only: dob_year_only,
              should_proof_state_id: true,
              stages: {
                state_id: {
                  client: 'aamva:state_id',
                  errors: {},
                  exception: nil,
                  success: true,
                  timed_out: false,
                  transaction_id: aamva_transaction_id,
                },
                resolution: {
                  client: 'lexisnexis:instant_verify',
                  errors: {},
                  exception: nil,
                  success: true,
                  timed_out: false,
                  transaction_id: lexisnexis_transaction_id,
                  reference: lexisnexis_reference,
                },
              },
            },
          )

          expect(result.dig(:transaction_id)).to eq(lexisnexis_transaction_id)
          expect(result.dig(:reference)).to eq(lexisnexis_reference)
        end
      end
    end

    context 'a stale job' do
      before { instance.enqueued_at = 10.minutes.ago }

      it 'bails and does not do any proofing' do
        expect(instance).to_not receive(:resolution_proofer)
        expect(instance).to_not receive(:state_id_proofer)

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end
  end
end
