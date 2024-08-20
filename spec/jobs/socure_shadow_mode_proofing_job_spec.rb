# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureShadowModeProofingJob do
  let(:job) do
    described_class.new
  end

  let(:document_capture_session) do
    DocumentCaptureSession.create(user:).tap do |dcs|
      dcs.create_proofing_session
    end
  end

  let(:document_capture_session_result_id) do
    document_capture_session.result_id
  end

  let(:applicant_pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
  end

  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      JSON.generate({ applicant_pii: }),
    )
  end

  let(:service_provider_issuer) {}

  let(:user) { create(:user) }

  let(:user_uuid) { user.uuid }

  let(:user_email) { user.email }

  let(:proofing_result) do
    FormResponse.new(
      success: true,
      errors: {},
      extra: {},
    )
  end

  let(:socure_idplus_base_url) { 'https://example.org' }

  before do
    document_capture_session.store_proofing_result(proofing_result)

    allow(IdentityConfig.store).to receive(:socure_idplus_base_url).
      and_return(socure_idplus_base_url)
  end

  describe '#perform' do
    subject(:perform) do
      allow(job).to receive(:create_analytics).and_return(analytics)

      job.perform(
        document_capture_session_result_id:,
        encrypted_arguments:,
        service_provider_issuer:,
        user_email:,
        user_uuid:,
      )
    end

    let(:analytics) do
      FakeAnalytics.new
    end

    let(:socure_response_body) do
      {
        referenceId: 'a1234b56-e789-0123-4fga-56b7c890d123',
        kyc: {
          reasonCodes: [
            'I919',
            'I914',
            'I905',
          ],
          fieldValidations: {
            firstName: 0.99,
            surName: 0.99,
            streetAddress: 0.99,
            city: 0.99,
            state: 0.99,
            zip: 0.99,
            mobileNumber: 0.99,
            dob: 0.99,
            ssn: 0.99,
          },
        },
        customerProfile: {
          customerUserId: '129',
          userId: 'u8JpWn4QsF3R7tA2',
        },
      }
    end

    before do
      stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
        to_return(
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(socure_response_body),
        )
    end

    context 'when document_capture_session_result_id is valid' do
      it 'makes a proofing call' do
        expect(job.proofer).to receive(:proof).and_call_original
        perform
      end

      it 'does not log an idv_socure_shadow_mode_proofing_result_missing event' do
        perform
        expect(analytics).not_to have_logged_event(:idv_socure_shadow_mode_proofing_result_missing)
      end

      it 'logs an event' do
        perform
        expect(analytics).to have_logged_event(
          :idv_socure_shadow_mode_proofing_result,
          user_id: user.uuid,
          resolution_result: {
            errors: {},
            extra: {},
            serialize_error_details_only: false,
            success: true,
          },
          socure_result: {
            attributes_requiring_additional_verification: [],
            can_pass_with_additional_verification: false,
            errors: { reason_codes: ['I905', 'I914', 'I919'] },
            exception: nil,
            reference: '',
            success: true,
            timed_out: false,
            transaction_id: 'a1234b56-e789-0123-4fga-56b7c890d123',
            vendor_name: 'socure_kyc',
            vendor_workflow: nil,
          },
        )
      end

      context 'when socure proofer raises an error' do
        before do
          allow(job.proofer).to receive(:proof).and_raise
        end

        it 'does not squash the error' do
          # The Proofer converts errors raised during requests into results
          # with the `exception` property set. Any other error
          expect { perform }.to raise_error
        end
      end
    end

    context 'when document_capture_session_result_id is not valid' do
      let(:document_capture_session_result_id) { 'some-id-that-is-not-valid' }

      it 'logs an idv_socure_shadow_mode_proofing_result_missing event' do
        perform

        expect(analytics).to have_logged_event(
          :idv_socure_shadow_mode_proofing_result_missing,
          user_id: user.uuid,
        )
      end
    end

    context 'when job is stale' do
      before do
        allow(job).to receive(:stale_job?).and_return(true)
      end
      it 'raises StaleJobError' do
        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end

    context 'when user is not found' do
      let(:user_uuid) { 'some-user-id-that-does-not-exist' }
      it 'raises an error' do
        expect do
          perform
        end.to raise_error(RuntimeError, 'User not found: some-user-id-that-does-not-exist')
      end
    end

    context 'when encrypted_arguments cannot be decrypted' do
      let(:encrypted_arguments) { 'bG9sIHRoaXMgaXMgbm90IGV2ZW4gZW5jcnlwdGVk' }
      it 'raises an error' do
        expect { perform }.to raise_error(Encryption::EncryptionError)
      end
    end

    context 'when encrypted_arguments contains invalid JSON' do
      let(:encrypted_arguments) do
        Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
          'this is not valid JSON',
        )
      end
      it 'raises an error' do
        expect { perform }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe '#build_applicant' do
    subject(:build_applicant) do
      job.build_applicant(encrypted_arguments:, user_email:)
    end

    it 'builds an applicant structure that looks right' do
      expect(build_applicant).to eql(
        {
          first_name: 'FAKEY',
          last_name: 'MCFAKERSON',
          address1: '1 FAKE RD',
          address2: nil,
          city: 'GREAT FALLS',
          state: 'MT',
          zipcode: '59010-1234',
          phone: '12025551212',
          dob: '1938-10-06',
          ssn: '900-66-1234',
          email: user.email,
        },
      )
    end
  end

  describe '#create_analytics' do
    it 'creates an Analytics instance with user and sp configured' do
      analytics = job.create_analytics(
        user:,
        service_provider_issuer:,
      )
      expect(analytics.sp).to eql(service_provider_issuer)
      expect(analytics.user).to eql(user)
    end
  end

  describe '#proofer' do
    let(:service_provider_issuer) { 'some-issuer' }
    it 'returns a configured proofer' do
      allow(IdentityConfig.store).to receive(:socure_idplus_api_key).and_return('an-api-key')
      allow(IdentityConfig.store).to receive(:socure_idplus_base_url).and_return('https://example.org')
      allow(IdentityConfig.store).to receive(:socure_idplus_timeout_in_seconds).and_return(6)

      expect(job.proofer.config.to_h).to eql(
        api_key: 'an-api-key',
        base_url: 'https://example.org',
        timeout: 6,
      )
    end
  end
end
