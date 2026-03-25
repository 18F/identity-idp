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
      Idp::Constants.mock_idv_applicant_with_ssn
    end
    let(:document_capture_session) do
      create(:document_capture_session, user:, result_id: SecureRandom.hex)
    end
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
    let(:proofing_vendor) do
      IdentityConfig.store.idv_resolution_default_vendor
    end

    subject(:agent) { Idv::Agent.new(applicant) }

    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
      reload_ab_tests
    end

    after do
      reload_ab_tests
    end

    describe '#proof_resolution' do
      subject(:proof_resolution) do
        agent.proof_resolution(
          document_capture_session,
          trace_id: trace_id,
          threatmetrix_session_id: nil,
          request_ip: request_ip,
          hybrid_mobile_threatmetrix_session_id: nil,
          hybrid_mobile_request_ip: nil,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          proofing_vendor:,
        )
      end

      subject(:result) do
        proof_resolution
        document_capture_session.load_proofing_result.result
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
