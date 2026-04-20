require 'rails_helper'

RSpec.describe ProofingAgent::ProofUser do
  let(:user) { create(:user) }
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:trace_id) { SecureRandom.uuid }
  let(:webhook_url) { 'https://example.com/webhook' }
  let(:issuer) { 'https://rp1.serviceprovider.com/auth/saml/metadata' }
  let(:document_capture_session) do
    create(:document_capture_session, user:, issuer:, result_id: SecureRandom.hex)
  end
  let(:transaction_id) { document_capture_session.uuid }
  let(:proofing_vendor) do
    IdentityConfig.store.idv_resolution_default_vendor
  end

  let(:state_id_applicant) do
    {
      suspected_fraud: false,
      email: 'test@example.com',
      first_name: 'John',
      last_name: 'Doe',
      dob: '1990-01-01',
      phone: '(555) 123-4567',
      ssn: '123-45-6789',
      id_type: 'drivers_license',
      state_id: {
        document_number: 'D1234567',
        jurisdiction: 'CA',
        expiration_date: '2030-01-01',
        issue_date: '2020-01-01',
        address1: '123 Main St',
        address2: 'Apt 4',
        city: 'San Francisco',
        state: 'CA',
        zip_code: '94105',
      },
    }
  end

  let(:passport_applicant) do
    {
      suspected_fraud: false,
      email: 'test@example.com',
      first_name: 'Jane',
      last_name: 'Smith',
      dob: '1985-06-15',
      phone: '(555) 987-6543',
      ssn: '987-65-4321',
      id_type: 'passport',
      passport: {
        expiration_date: '2030-06-15',
        issue_date: '2020-06-15',
        issuing_country_code: 'USA',
        mrz: 'P<USATRAVELER<<HAPPY<<<<<<<<<<<<<<<<<<<1234567890USA8501019M2412317<<<<<<<<<<<4',
      },
      residential_address: {
        address1: '456 Side St',
        address2: 'Apt 123',
        city: 'Boston',
        state: 'MA',
        zip_code: '02101',
      },
    }
  end

  def call_service(applicant: state_id_applicant)
    described_class.new(applicant).call(
      document_capture_session:,
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      trace_id:,
      transaction_id:,
      proofing_vendor:,
      webhook_url:,
    )
  end

  def decrypt_applicant_pii(args)
    decrypted = Encryption::Encryptors::BackgroundProofingArgEncryptor.new
      .decrypt(args[:encrypted_arguments])
    JSON.parse(decrypted, symbolize_names: true)
  end

  describe '#call' do
    context 'when ruby_workers_idv_enabled is true' do
      before do
        allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(true)
      end

      context 'with a state ID applicant' do
        it 'dispatches ProofingAgentJob via perform_later' do
          expect(ProofingAgentJob).to receive(:perform_later).once
          call_service
        end

        it 'passes service_provider_issuer from the document_capture_session' do
          expect(ProofingAgentJob).to receive(:perform_later).with(
            hash_including(service_provider_issuer: issuer),
          )
          call_service
        end

        it 'passes all required job arguments' do
          expect(ProofingAgentJob).to receive(:perform_later).with(
            hash_including(
              trace_id:,
              result_id: document_capture_session.result_id,
              user_id: document_capture_session.user_id,
              service_provider_issuer: issuer,
              ipp_enrollment_in_progress: false,
              proofing_vendor:,
              proofing_agent_id:,
              proofing_location_id:,
              correlation_id:,
              webhook_url:,
              transaction_id:,
            ),
          )
          call_service
        end

        it 'passes encrypted_arguments containing the transformed applicant PII' do
          expect(ProofingAgentJob).to receive(:perform_later) do |args|
            parsed = decrypt_applicant_pii(args)
            expect(parsed[:applicant_pii]).to include(
              first_name: 'John',
              last_name: 'Doe',
              document_type_received: 'drivers_license',
              state_id_number: 'D1234567',
              state_id_jurisdiction: 'CA',
            )
          end
          call_service
        end

        it 'sets same_address_as_id to true when no residential_address is given' do
          expect(ProofingAgentJob).to receive(:perform_later) do |args|
            parsed = decrypt_applicant_pii(args)
            expect(parsed[:applicant_pii][:same_address_as_id]).to eq('true')
          end
          call_service
        end
      end

      context 'with a passport applicant' do
        it 'dispatches ProofingAgentJob via perform_later' do
          expect(ProofingAgentJob).to receive(:perform_later).once
          call_service(applicant: passport_applicant)
        end

        it 'passes all required job arguments' do
          expect(ProofingAgentJob).to receive(:perform_later).with(
            hash_including(
              trace_id:,
              result_id: document_capture_session.result_id,
              user_id: document_capture_session.user_id,
              service_provider_issuer: issuer,
              ipp_enrollment_in_progress: false,
              proofing_vendor:,
              proofing_agent_id:,
              proofing_location_id:,
              correlation_id:,
              webhook_url:,
              transaction_id:,
            ),
          )
          call_service(applicant: passport_applicant)
        end

        it 'passes encrypted passport PII in encrypted_arguments' do
          expect(ProofingAgentJob).to receive(:perform_later) do |args|
            parsed = decrypt_applicant_pii(args)
            expect(parsed[:applicant_pii]).to include(
              first_name: 'Jane',
              last_name: 'Smith',
              document_type_received: 'passport',
              issuing_country_code: 'USA',
            )
          end
          call_service(applicant: passport_applicant)
        end

        it 'sets same_address_as_id to false when residential_address is given' do
          expect(ProofingAgentJob).to receive(:perform_later) do |args|
            parsed = decrypt_applicant_pii(args)
            expect(parsed[:applicant_pii][:same_address_as_id]).to eq('false')
          end
          call_service(applicant: passport_applicant)
        end
      end
    end

    context 'when ruby_workers_idv_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
      end

      it 'dispatches ProofingAgentJob via perform_now' do
        expect(ProofingAgentJob).to receive(:perform_now).once
        call_service
      end

      it 'passes all required job arguments' do
        expect(ProofingAgentJob).to receive(:perform_now).with(
          hash_including(
            trace_id:,
            result_id: document_capture_session.result_id,
            user_id: document_capture_session.user_id,
            service_provider_issuer: issuer,
            ipp_enrollment_in_progress: false,
            proofing_vendor:,
            proofing_agent_id:,
            proofing_location_id:,
            correlation_id:,
            webhook_url:,
            transaction_id:,
          ),
        )
        call_service
      end
    end
  end
end
