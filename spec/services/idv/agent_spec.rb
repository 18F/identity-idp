require 'rails_helper'
require 'ostruct'

describe Idv::Agent do
  include IdvHelper

  let(:user) { build(:user) }

  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end

  describe 'instance' do
    let(:applicant) { { foo: 'bar' } }
    let(:trace_id) { SecureRandom.uuid }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:issuer) { 'fake-issuer' }
    let(:friendly_name) { 'fake-name' }
    let(:app_id) { 'fake-app-id' }

    let(:agent) { Idv::Agent.new(applicant) }

    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
        allow_threatmetrix: true,
      )
    end

    describe '#proof_resolution' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }

      context 'proofing state_id enabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT.merge(uuid: user.uuid, ssn: '444-55-6666'),
          )
          agent.proof_resolution(
            document_capture_session,
            should_proof_state_id: true,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            issuer: issuer,
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages].key?(:state_id)).to eq false
        end

        it 'does proof state_id if resolution succeeds' do
          agent = Idv::Agent.new(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: user.uuid))
          agent.proof_resolution(
            document_capture_session,
            should_proof_state_id: true,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            issuer: issuer,
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages][:state_id]).to include(
            client: 'StateIdMock',
            transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
          )
        end
      end

      context 'proofing state_id disabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT.merge(uuid: user.uuid, ssn: '444-55-6666'),
          )
          agent.proof_resolution(
            document_capture_session,
            should_proof_state_id: true,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            issuer: issuer,
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages].key?(:state_id)).to eq false
        end

        it 'does not proof state_id if resolution succeeds' do
          agent = Idv::Agent.new(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: user.uuid))
          agent.proof_resolution(
            document_capture_session,
            should_proof_state_id: false,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            issuer: issuer,
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages]).to_not include(
            state_id: 'StateIdMock',
            transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
          )
        end

        it 'returns a successful result if SSN does not start with 900 but is in SSN allowlist' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT.merge(uuid: user.uuid, ssn: '999-99-9999'),
          )

          agent.proof_resolution(
            document_capture_session,
            should_proof_state_id: false,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            issuer: issuer,
          )
          result = document_capture_session.load_proofing_result.result

          expect(result).to include(
            success: true,
          )
        end
      end

      it 'returns an unsuccessful result and notifies exception trackers if an exception occurs' do
        agent = Idv::Agent.new(
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
            uuid: user.uuid,
            first_name: 'Time Exception',
          ),
        )

        agent.proof_resolution(
          document_capture_session,
          should_proof_state_id: true,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          issuer: issuer,
        )
        result = document_capture_session.load_proofing_result.result

        expect(result[:exception]).to start_with('#<Proofing::TimeoutError: ')
        expect(result).to include(
          success: false,
          timed_out: true,
        )
      end
    end

    describe '#proof_address' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
      let(:user_id) { SecureRandom.random_number(1000) }
      let(:issuer) { build(:service_provider).issuer }

      it 'proofs addresses successfully with valid information' do
        agent = Idv::Agent.new(
          uuid: SecureRandom.uuid,
          first_name: 'Fakey',
          last_name: 'Fakersgerald',
          dob: 50.years.ago.to_date.to_s,
          ssn: '666-12-1234',
          phone: Faker::PhoneNumber.cell_phone,
        )
        agent.proof_address(
          document_capture_session,
          trace_id: trace_id,
          user_id: user_id,
          issuer: issuer,
        )
        result = document_capture_session.load_proofing_result[:result]
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq true
      end

      it 'fails to proof addresses with invalid information' do
        agent = Idv::Agent.new(phone: bad_phone)
        agent.proof_address(
          document_capture_session, trace_id: trace_id, user_id: user_id, issuer: issuer
        )
        result = document_capture_session.load_proofing_result[:result]
        expect(result[:context][:stages]).to include({ address: 'AddressMock' })
        expect(result[:success]).to eq false
      end
    end
  end
end
