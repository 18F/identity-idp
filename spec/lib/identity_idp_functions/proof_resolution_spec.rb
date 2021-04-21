require 'rails_helper'
require 'identity_idp_functions/proof_resolution'

RSpec.describe IdentityIdpFunctions::ProofResolution do
  let(:trace_id) { SecureRandom.uuid }
  let(:lexisnexis_transaction_id) { SecureRandom.uuid }
  let(:aamva_transaction_id) { SecureRandom.uuid }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      address1: '123 Main St.',
      city: 'Milwaukee',
      state: 'WI',
      dob: '01/01/1970',
      ssn: '123456789',
      zipcode: '53206',
      phone: '18888675309',
      state_id_number: '123456',
      state_id_type: 'drivers_license',
      state_id_jurisdiction: 'WI',
    }
  end
  let(:logger) { Logger.new('/dev/null')  }

  describe '#proof' do
    let(:should_proof_state_id) { true }
    let(:lexisnexis_proofer) { instance_double(LexisNexis::InstantVerify::Proofer) }
    let(:aamva_proofer) { instance_double(Aamva::Proofer) }
    let(:dob_year_only) { false }

    subject(:function) do
      IdentityIdpFunctions::ProofResolution.new(
        applicant_pii: applicant_pii,
        should_proof_state_id: should_proof_state_id,
        trace_id: trace_id,
        logger: logger,
        dob_year_only: dob_year_only,
      )
    end

    before do
      allow(function).to receive(:aamva_proofer).and_return(aamva_proofer)
    end

    context 'webmock lexisnexis' do
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(body: lexisnexis_response.to_json)

        allow(AppConfig.env).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(AppConfig.env).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_username).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_password).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
        allow(AppConfig.env).to receive(:lexisnexis_instant_verify_workflow).and_return('aaa')
        allow(AppConfig.env).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
        allow(AppConfig.env).to receive(:lexisnexis_instant_verify_workflow).and_return('aaa')

        allow(aamva_proofer).to receive(:proof).
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
        result = function.proof

        expect(result).to eq(
          resolution_result: {
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
          },
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
          result = function.proof

          expect(result).to match(
            resolution_result: {
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
            },
          )
        end
      end
    end

    context 'stubbing vendors' do
      before do
        allow(function).to receive(:lexisnexis_proofer).and_return(lexisnexis_proofer)
      end

      context 'with a successful response from the proofer' do
        before do
          expect(lexisnexis_proofer).to receive(:proof).
            and_return(Proofer::Result.new)

          expect(aamva_proofer).to receive(:proof).
            and_return(Proofer::Result.new)
        end

        it 'logs the trace_id and timing info' do
          expect(logger).to receive(:info).with(hash_including(:timing, trace_id: trace_id))

          function.proof
        end
      end

      context 'does not call state id with an unsuccessful response from the proofer' do
        it 'posts back to the callback url' do
          expect(lexisnexis_proofer).to receive(:proof).
            and_return(Proofer::Result.new(exception: 'error'))
          expect(aamva_proofer).not_to receive(:proof)

          function.proof
        end
      end

      context 'no state_id proof' do
        let(:should_proof_state_id) { false }

        it 'does not call state_id proof if resolution proof is successful' do
          expect(lexisnexis_proofer).to receive(:proof).
            and_return(Proofer::Result.new)

          expect(aamva_proofer).not_to receive(:proof)
          function.proof
        end
      end

      context 'checking DOB year only' do
        let(:dob_year_only) { true }

        it 'only sends the birth year to LexisNexis (extra applicant attribute)' do
          expect(aamva_proofer).to receive(:proof).and_return(Proofer::Result.new)
          expect(lexisnexis_proofer).to receive(:proof).
            with(hash_including(dob_year_only: true)).
            and_return(Proofer::Result.new)

          function.proof
        end

        it 'does not check LexisNexis when AAMVA proofing does not match' do
          expect(aamva_proofer).to receive(:proof).and_return(Proofer::Result.new(exception: 'error'))
          expect(lexisnexis_proofer).to_not receive(:proof)

          function.proof
        end

        it 'logs the correct context' do
          expect(aamva_proofer).to receive(:proof).
            and_return(Proofer::Result.new(transaction_id: aamva_transaction_id))
          expect(lexisnexis_proofer).to receive(:proof).
            and_return(Proofer::Result.new(transaction_id: lexisnexis_transaction_id))

          result = function.proof

          expect(result.dig(:resolution_result, :context, :stages)).to eq [
            { state_id: 'aamva:state_id', transaction_id: aamva_transaction_id },
            { resolution: 'lexisnexis:instant_verify', transaction_id: lexisnexis_transaction_id },
          ]

          expect(result.dig(:resolution_result, :transaction_id)).to eq(lexisnexis_transaction_id)
        end
      end
    end
  end
end
