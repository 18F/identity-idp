require 'rails_helper'
require 'ostruct'

RSpec.describe Idv::Agent do
  let(:user) { create(:user) }

  describe 'instance' do
    let(:trace_id) { SecureRandom.uuid }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:issuer) { 'fake-issuer' }
    let(:friendly_name) { 'fake-name' }
    let(:app_id) { 'fake-app-id' }
    let(:ipp_enrollment_in_progress) { false }
    let(:applicant) do
      Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN
    end
    let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
    let(:session) { {} }
    let(:user_session) { {} }
    let(:idv_session) do
      Idv::Session.new(
        user_session:,
        current_user: user,
        service_provider: issuer,
      ).tap do |idv_session|
        idv_session.pii_from_doc = applicant
      end
    end
    let(:proofing_components) do
      Idv::ProofingComponents.new(
        idv_session:,
        session:,
        user:,
        user_session:,
      )
    end

    subject(:agent) { Idv::Agent.new(applicant) }

    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
    end

    describe '#proof_resolution' do
      subject(:proof_resolution) do
        agent.proof_resolution(
          document_capture_session,
          trace_id: trace_id,
          user_id: user.id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          proofing_components:,
        )
      end

      subject(:result) do
        proof_resolution
        document_capture_session.load_proofing_result.result
      end

      context 'proofing in an AAMVA state' do
        context 'when resolution fails' do
          let(:applicant) do
            super().merge(ssn: '444-55-6666')
          end

          it 'does not proof state_id' do
            expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
            expect(result[:context][:stages][:state_id][:vendor_name]).to(
              eq('UnsupportedJurisdiction'),
            )
          end
        end
        context 'when resolution succeeds' do
          it 'proofs state_id' do
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
      end

      context 'non-AAMVA state' do
        let(:applicant) do
          super().merge(state_id_jurisdiction: 'NY')
        end

        context 'when resolution fails' do
          let(:applicant) do
            super().merge(ssn: '444-55-6666')
          end

          it 'does not proof state_id' do
            expect(result[:errors][:ssn]).to eq ['Unverified SSN.']
            expect(result[:context][:stages][:state_id][:vendor_name]).to(
              eq('UnsupportedJurisdiction'),
            )
          end
        end

        context 'when resolution succeeds' do
          it 'does not proof state_id' do
            expect(result[:context][:stages]).to_not include(
              state_id: 'StateIdMock',
              transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID,
            )
          end
        end
      end

      context 'when SSN does not start with 900 but is in SSN allowlist' do
        let(:applicant) do
          super().merge(ssn: '999-99-9999')
        end

        it 'returns a successful result' do
          expect(result).to include(
            success: true,
          )
        end
      end

      it 'passes the correct service provider to the ResolutionProofingJob' do
        issuer = 'https://rp1.serviceprovider.com/auth/saml/metadata'
        document_capture_session.update!(issuer: issuer)

        expect(ResolutionProofingJob).to receive(:perform_later).with(
          hash_including(
            service_provider_issuer: issuer,
          ),
        )

        proof_resolution
      end

      it 'passes proofing components to ResolutionProofingJob' do
        expect(ResolutionProofingJob).to receive(:perform_later).with(
          hash_including(
            proofing_components: {
              document_check: 'mock',
              document_type: 'state_id',
            },
          ),
        )
        proof_resolution
      end

      context 'when a proofing timeout occurs' do
        let(:applicant) do
          super().merge(first_name: 'Time Exception')
        end
        it 'returns unsuccessful result and notifies exception trackers if an exception occurs' do
          expect(result[:exception].to_s).to include('resolution mock timeout')
          expect(result).to include(
            success: false,
            timed_out: true,
          )
        end
      end

      context 'in-person proofing is enabled' do
        let(:ipp_enrollment_in_progress) { true }
        let(:applicant) do
          Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS
        end

        it 'returns a successful result if resolution passes' do
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
      let(:applicant) do
        super().merge(
          phone: Faker::PhoneNumber.cell_phone,
        )
      end

      subject(:proof_address) do
        agent.proof_address(
          document_capture_session,
          trace_id: trace_id,
          user_id: user.id,
          issuer: issuer,
        )
      end

      subject(:result) do
        proof_address
        document_capture_session.load_proofing_result[:result]
      end

      it 'proofs addresses successfully with valid information' do
        expect(result[:vendor_name]).to eq('AddressMock')
        expect(result[:success]).to eq true
      end

      context 'when address has invalid information' do
        let(:applicant) do
          super().merge(
            phone: Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
          )
        end

        it 'fails to proof address' do
          expect(result[:vendor_name]).to eq('AddressMock')
          expect(result[:success]).to eq false
        end
      end
    end
  end
end
