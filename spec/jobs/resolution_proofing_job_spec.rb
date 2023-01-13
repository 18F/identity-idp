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
  let(:should_proof_state_id) { true }

  let(:lexisnexis_transaction_id) { SecureRandom.uuid }
  let(:lexisnexis_reference) { SecureRandom.uuid }
  let(:aamva_transaction_id) { '1234-abcd-efgh' }
  let(:resolution_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      class: Proofing::LexisNexis::InstantVerify::Proofer,
    )
  end
  let(:state_id_proofer) do
    Proofing::Aamva::Proofer.new(AamvaFixtures.example_config.to_h)
  end
  let(:ddp_proofer) do
    Proofing::LexisNexis::Ddp::Proofer.new(
      LexisNexisFixtures.example_ddp_config.to_h,
    )
  end
  let(:trace_id) { SecureRandom.uuid }
  let(:user) { create(:user, :signed_up) }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:threatmetrix_request_id) { Proofing::Mock::DdpMockClient::TRANSACTION_ID }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:friendly_name) { 'fake-name' }
  let(:app_id) { 'fake-app-id' }
  let(:ddp_response_body) do
    JSON.parse(LexisNexisFixtures.ddp_success_redacted_response_json, symbolize_names: true)
  end

  describe '.perform_later' do
    it 'stores results' do
      ResolutionProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        should_proof_state_id: should_proof_state_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user.id,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
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
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user.id,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
      )
    end

    context 'webmock lexisnexis, threatmetrix, and AAMVA' do
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(body: lexisnexis_response.to_json)

        stub_request(
          :post,
          'https://www.example.com/api/session-query',
        ).to_return(body: LexisNexisFixtures.ddp_success_response_json)

        stub_request(:post, AamvaFixtures.example_config.auth_url).
          to_return(
            { body: AamvaFixtures.security_token_response },
            { body: AamvaFixtures.authentication_token_response },
          )
        stub_request(:post, AamvaFixtures.example_config.verification_url).
          to_return(body: AamvaFixtures.verification_response)

        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)

        allow(IdentityConfig.store).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(IdentityConfig.store).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_username).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_password).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_base_url).
          and_return('https://lexisnexis.example.com/')
        allow(IdentityConfig.store).to receive(:lexisnexis_instant_verify_workflow).
          and_return('aaa')

        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)

        Proofing::Mock::DeviceProfilingBackend.new.record_profiling_result(
          session_id: threatmetrix_session_id,
          result: 'pass',
        )
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

      it 'returns results and adds threatmetrix proofing components' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        result_context = result[:context]
        result_context_stages = result_context[:stages]
        result_context_stages_resolution = result_context_stages[:resolution]
        result_context_stages_state_id = result_context_stages[:state_id]
        result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

        expect(result[:exception]).to be_nil
        expect(result[:errors]).to eq({})
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false

        # result[:context]
        expect(result_context[:should_proof_state_id])

        # result[:context][:stages][:resolution]
        expect(result_context_stages_resolution[:vendor_name]).
          to eq('lexisnexis:instant_verify')
        expect(result_context_stages_resolution[:errors]).to eq({})
        expect(result_context_stages_resolution[:exception]).to eq(nil)
        expect(result_context_stages_resolution[:success]).to eq(true)
        expect(result_context_stages_resolution[:timed_out]).to eq(false)
        expect(result_context_stages_resolution[:transaction_id]).to eq(lexisnexis_transaction_id)
        expect(result_context_stages_resolution[:reference]).to eq(lexisnexis_reference)
        expect(result_context_stages_resolution[:can_pass_with_additional_verification]).
          to eq(false)
        expect(result_context_stages_resolution[:attributes_requiring_additional_verification]).
          to eq([])

        # result[:context][:stages][:state_id]
        expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
        expect(result_context_stages_state_id[:errors]).to eq({})
        expect(result_context_stages_state_id[:exception]).to eq(nil)
        expect(result_context_stages_state_id[:success]).to eq(true)
        expect(result_context_stages_state_id[:timed_out]).to eq(false)
        expect(result_context_stages_state_id[:transaction_id]).to eq(aamva_transaction_id)
        expect(result_context_stages_state_id[:verified_attributes]).to eq(
          %w[address state_id_number state_id_type dob last_name first_name],
        )

        # result[:context][:stages][:threatmetrix]
        expect(result_context_stages_threatmetrix[:client]).to eq('DdpMock')
        expect(result_context_stages_threatmetrix[:errors]).to eq({})
        expect(result_context_stages_threatmetrix[:exception]).to eq(nil)
        expect(result_context_stages_threatmetrix[:success]).to eq(true)
        expect(result_context_stages_threatmetrix[:timed_out]).to eq(false)
        expect(result_context_stages_threatmetrix[:transaction_id]).to eq(threatmetrix_request_id)
        expect(result_context_stages_threatmetrix[:review_status]).to eq('pass')
        expect(result_context_stages_threatmetrix[:response_body]).to eq(ddp_response_body)

        proofing_component = user.proofing_component
        expect(proofing_component.threatmetrix).to equal(true)
        expect(proofing_component.threatmetrix_review_status).to eq('pass')
      end

      context 'failed response from lexisnexis' do
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

          result_context = result[:context]
          result_context_stages = result_context[:stages]
          result_context_stages_resolution = result_context_stages[:resolution]
          result_context_stages_state_id = result_context_stages[:state_id]
          result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

          expect(result[:exception]).to be_nil
          expect(result[:errors]).to match(
            base: [
              a_string_starting_with(
                'Response error with code \'invalid_transaction_initiate\':',
              ),
            ],
          )
          expect(result[:success]).to be false
          expect(result[:timed_out]).to be false

          # result[:context]
          expect(result_context[:should_proof_state_id])

          # result[:context][:stages][:resolution]
          expect(result_context_stages_resolution[:vendor_name]).
            to eq('lexisnexis:instant_verify')
          expect(result_context_stages_resolution[:errors][:base].first).to match(
            a_string_starting_with('Response error with code \'invalid_transaction_initiate\':'),
          )
          expect(result_context_stages_resolution[:exception]).to eq(nil)
          expect(result_context_stages_resolution[:success]).to eq(false)
          expect(result_context_stages_resolution[:timed_out]).to eq(false)
          expect(result_context_stages_resolution[:transaction_id]).
            to eq(lexisnexis_transaction_id)
          expect(result_context_stages_resolution[:reference]).to eq(lexisnexis_reference)
          expect(result_context_stages_resolution[:can_pass_with_additional_verification]).
            to eq(false)
          expect(result_context_stages_resolution[:attributes_requiring_additional_verification]).
            to eq([])

          # result[:context][:stages][:state_id]
          expect(result_context_stages_state_id[:vendor_name]).to eq('aamva:state_id')
          expect(result_context_stages_state_id[:errors]).to eq({})
          expect(result_context_stages_state_id[:exception]).to eq(nil)
          expect(result_context_stages_state_id[:success]).to eq(true)
          expect(result_context_stages_state_id[:timed_out]).to eq(false)
          expect(result_context_stages_state_id[:transaction_id]).to eq('1234-abcd-efgh')
          expect(result_context_stages_state_id[:verified_attributes]).to eq(
            ['address', 'state_id_number', 'state_id_type', 'dob', 'last_name', 'first_name'],
          )

          # result[:context][:stages][:threatmetrix]
          expect(result_context_stages_threatmetrix[:client]).to eq('DdpMock')
          expect(result_context_stages_threatmetrix[:errors]).to eq({})
          expect(result_context_stages_threatmetrix[:exception]).to eq(nil)
          expect(result_context_stages_threatmetrix[:success]).to eq(true)
          expect(result_context_stages_threatmetrix[:timed_out]).to eq(false)
          expect(result_context_stages_threatmetrix[:transaction_id]).
            to eq(threatmetrix_request_id)
          expect(result_context_stages_threatmetrix[:response_body]).to eq(ddp_response_body)
        end
      end

      context 'no threatmetrix_session_id' do
        let(:threatmetrix_session_id) { nil }
        it 'does not attempt to create a ddp proofer' do
          perform

          expect(instance).not_to receive(:lexisnexis_ddp_proofer)
        end
      end
    end

    context 'stubbing vendors and threatmetrix' do
      before do
        allow(instance).to receive(:resolution_proofer).and_return(resolution_proofer)
        allow(instance).to receive(:state_id_proofer).and_return(state_id_proofer)
        allow(instance).to receive(:lexisnexis_ddp_proofer).and_return(ddp_proofer)
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        stub_request(:post, 'https://example.com/api/session-query').
          with(
            body: hash_including('api_key' => 'test_api_key'),
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization' => 'Basic Og==',
              'Content-Type' => 'application/json',
              'User-Agent' => 'Faraday v2.6.0',
            },
          ).
          to_return(
            status: 200,
            body: LexisNexisFixtures.ddp_success_response_json,
            headers: {},
          )
      end

      context 'with a successful response from the proofer' do
        before do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofing::Result.new)
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofing::Result.new)
          Proofing::Mock::DeviceProfilingBackend.new.record_profiling_result(
            session_id: threatmetrix_session_id,
            result: 'pass',
          )
        end

        it 'logs the trace_id and timing info for ProofResolution and the Threatmetrix info' do
          expect(instance).to receive(:logger_info_hash).ordered.with(
            hash_including(
              name: 'ThreatMetrix',
              threatmetrix_request_id: '1234',
              threatmetrix_success: true,
              user_id: user.uuid,
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

          proofing_component = user.proofing_component
          expect(proofing_component.threatmetrix).to equal(true)
          expect(proofing_component.threatmetrix_review_status).to eq('pass')
        end

        context 'nil response body from ddp' do
          let(:ddp_result) { Proofing::Result.new(response_body: nil) }

          before do
            expect(ddp_proofer).to receive(:proof).and_return(ddp_result)
          end

          it 'does not blow up' do
            perform

            result = document_capture_session.load_proofing_result[:result]

            result_context = result[:context]
            result_context_stages = result_context[:stages]
            result_context_stages_threatmetrix = result_context_stages[:threatmetrix]

            # result[:context][:stages][:threatmetrix]
            expect(result_context_stages_threatmetrix[:response_body]).to eq(
              error: 'TMx response body was empty',
            )
          end
        end
      end

      context 'does call state id with an unsuccessful response from the proofer' do
        it 'posts back to the callback url' do
          expect(resolution_proofer).to receive(:proof).
            and_return(Proofing::Result.new(exception: 'error'))
          expect(state_id_proofer).to receive(:proof).
            and_return(Proofing::Result.new)

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
