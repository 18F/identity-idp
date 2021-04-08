require 'rails_helper'
require 'ostruct'

describe Idv::Agent do
  include IdvHelper

  let(:bad_phone) do
    IdentityIdpFunctions::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end

  describe 'instance' do
    let(:applicant) { { foo: 'bar' } }
    let(:trace_id) { SecureRandom.uuid }

    let(:agent) { Idv::Agent.new(applicant) }

    describe '#proof_resolution' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }

      context 'proofing state_id enabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new({ ssn: '444-55-6666', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          agent.proof_resolution(
            document_capture_session, should_proof_state_id: true, trace_id: trace_id
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages]).to_not include(
            state_id: 'StateIdMock',
            transaction_id: IdentityIdpFunctions::StateIdMockClient::TRANSACTION_ID,
          )
        end

        it 'does proof state_id if resolution succeeds' do
          agent = Idv::Agent.new(
            ssn: '444-55-8888',
            first_name: Faker::Name.first_name,
            zipcode: '11111',
            state_id_number: '123456789',
            state_id_type: 'drivers_license',
            state_id_jurisdiction: 'MD',
          )
          agent.proof_resolution(
            document_capture_session, should_proof_state_id: true, trace_id: trace_id
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages]).to include(
            state_id: 'StateIdMock',
            transaction_id: IdentityIdpFunctions::StateIdMockClient::TRANSACTION_ID,
          )
        end
      end

      context 'proofing state_id disabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new({ ssn: '444-55-6666', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          agent.proof_resolution(
            document_capture_session, should_proof_state_id: true, trace_id: trace_id
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages]).to_not include(
            state_id: 'StateIdMock',
            transaction_id: IdentityIdpFunctions::StateIdMockClient::TRANSACTION_ID,
          )
        end

        it 'does not proof state_id if resolution succeeds' do
          agent = Idv::Agent.new({ ssn: '444-55-8888', first_name: Faker::Name.first_name,
                                   zipcode: '11111' })
          agent.proof_resolution(
            document_capture_session, should_proof_state_id: false, trace_id: trace_id
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages]).to_not include(
            state_id: 'StateIdMock',
            transaction_id: IdentityIdpFunctions::StateIdMockClient::TRANSACTION_ID,
          )
        end
      end

      it 'returns an unsuccessful result and notifies exception trackers if an exception occurs' do
        agent = Idv::Agent.new(ssn: '444-55-8888', first_name: 'Time Exception',
                               zipcode: '11111')

        agent.proof_resolution(
          document_capture_session, should_proof_state_id: true, trace_id: trace_id
        )
        result = document_capture_session.load_proofing_result.result

        expect(result[:exception]).to start_with('#<Proofer::TimeoutError: ')
        expect(result).to include(
          success: false,
          timed_out: true,
        )
      end
    end

    describe '#proof_address' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }

      it 'proofs addresses successfully with valid information' do
        agent = Idv::Agent.new({ phone: Faker::PhoneNumber.cell_phone })
        agent.proof_address(document_capture_session, trace_id: trace_id)
        result = document_capture_session.load_proofing_result[:result]
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq true
      end

      it 'fails to proof addresses with invalid information' do
        agent = Idv::Agent.new(phone: bad_phone)
        agent.proof_address(document_capture_session, trace_id: trace_id)
        result = document_capture_session.load_proofing_result[:result]
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq false
      end
    end
  end
end
