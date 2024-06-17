require 'rails_helper'
require 'ostruct'

RSpec.describe Idv::Agent do
  let(:user) { create(:user) }

  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end

  describe 'instance' do
    let(:trace_id) { SecureRandom.uuid }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:issuer) { 'fake-issuer' }
    let(:friendly_name) { 'fake-name' }
    let(:app_id) { 'fake-app-id' }
    let(:ipp_enrollment_in_progress) { false }

    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
    end

    describe '#proof_resolution' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }

      context 'proofing in an AAMVA state' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT.merge(ssn: '444-55-6666'),
          )
          agent.proof_resolution(
            document_capture_session,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages][:state_id][:vendor_name]).to eq 'UnsupportedJurisdiction'
        end

        it 'does proof state_id if resolution succeeds' do
          agent = Idv::Agent.new(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN)
          agent.proof_resolution(
            document_capture_session,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages][:state_id]).to include(
            transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
            errors: {},
            exception: nil,
            success: true,
            timed_out: false,
            vendor_name: 'StateIdMock',
          )
        end
      end

      context 'proofing state_id disabled' do
        it 'does not proof state_id if resolution fails' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT.merge(
              ssn: '444-55-6666', state_id_jurisdiction: 'NY',
            ),
          )
          agent.proof_resolution(
            document_capture_session,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
          expect(result[:context][:stages][:state_id][:vendor_name]).to eq 'UnsupportedJurisdiction'
        end

        it 'does not proof state_id if resolution succeeds' do
          agent = Idv::Agent.new(
            Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
              state_id_jurisdiction: 'NY',
            ),
          )
          agent.proof_resolution(
            document_capture_session,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          )

          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages]).to_not include(
            state_id: 'StateIdMock',
            transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
          )
        end
      end

      it 'returns a successful result if SSN does not start with 900 but is in SSN allowlist' do
        agent = Idv::Agent.new(
          Idp::Constants::MOCK_IDV_APPLICANT.merge(ssn: '999-99-9999'),
        )

        agent.proof_resolution(
          document_capture_session,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        )
        result = document_capture_session.load_proofing_result.result

        expect(result).to include(
          success: true,
        )
      end

      it 'passes the correct service provider to the ResolutionProofingJob' do
        issuer = 'https://rp1.serviceprovider.com/auth/saml/metadata'
        document_capture_session.update!(issuer: issuer)
        agent = Idv::Agent.new(
          Idp::Constants::MOCK_IDV_APPLICANT.merge(ssn: '999-99-9999'),
        )

        expect(ResolutionProofingJob).to receive(:perform_later).with(
          hash_including(
            service_provider_issuer: issuer,
          ),
        )

        agent.proof_resolution(
          document_capture_session,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        )
      end

      it 'returns an unsuccessful result and notifies exception trackers if an exception occurs' do
        agent = Idv::Agent.new(
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(first_name: 'Time Exception'),
        )

        agent.proof_resolution(
          document_capture_session,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        )
        result = document_capture_session.load_proofing_result.result

        expect(result[:exception].to_s).to include('address mock timeout')
        expect(result).to include(
          success: false,
          timed_out: true,
        )
      end

      context 'in-person proofing is enabled' do
        let(:ipp_enrollment_in_progress) { true }

        it 'returns a successful result if resolution passes' do
          agent = Idv::Agent.new(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS)
          agent.proof_resolution(
            document_capture_session,
            trace_id: trace_id,
            user_id: user.id,
            threatmetrix_session_id: nil,
            request_ip: request_ip,
            ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          )
          result = document_capture_session.load_proofing_result.result
          expect(result[:context][:stages][:state_id]).to include(
            transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
            errors: {},
            exception: nil,
            success: true,
            timed_out: false,
          )
        end
      end
    end

    describe '#proof_address' do
      let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
      let(:user_id) { SecureRandom.random_number(1000) }
      let(:issuer) { build(:service_provider).issuer }

      it 'proofs addresses successfully with valid information' do
        agent = Idv::Agent.new(
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
        expect(result[:vendor_name]).to eq('AddressMock')
        expect(result[:success]).to eq true
      end

      it 'fails to proof addresses with invalid information' do
        agent = Idv::Agent.new(phone: bad_phone)
        agent.proof_address(
          document_capture_session, trace_id: trace_id, user_id: user_id, issuer: issuer
        )
        result = document_capture_session.load_proofing_result[:result]
        expect(result[:vendor_name]).to eq('AddressMock')
        expect(result[:success]).to eq false
      end
    end
  end
end
