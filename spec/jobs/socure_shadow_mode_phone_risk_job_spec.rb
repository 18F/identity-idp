# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureShadowModePhoneRiskJob do
  let(:job) do
    described_class.new
  end

  let(:user) { create(:user) }

  let(:user_uuid) { user.uuid }

  let(:user_email) { user.last_sign_in_email_address.email }

  let(:document_capture_session) do
    create(:document_capture_session, user:).tap do |dcs|
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

  let(:proofing_result) do
    Proofing::Mock::AddressMockClient.new.proof(phone: phone)
  end

  let(:phone) { applicant_pii[:phone] }

  let(:socure_idplus_base_url) { 'https://example.org' }

  before do
    proofing_result = Proofing::Mock::AddressMockClient.new.proof(phone:)
    document_capture_session.store_proofing_result(proofing_result)

    allow(IdentityConfig.store).to receive(:socure_idplus_base_url)
      .and_return(socure_idplus_base_url)
  end

  describe '#perform' do
    subject(:perform) do
      allow(job).to receive(:create_analytics).and_return(analytics)

      job.perform(
        document_capture_session_result_id:,
        encrypted_arguments:,
        service_provider_issuer: nil,
        user_uuid:,
      )
    end

    let(:analytics) do
      FakeAnalytics.new
    end

    let(:reference) { 'a1234b56-e789-0123-4fga-56b7c890d123' }

    let(:socure_response_body) do
      {
        referenceId: reference,
        namePhoneCorrelation: {
          reasonCodes: [
            'I123',
            'R567',
            'R890',
          ],
          score: 0.99,
        },
        phoneRisk: {
          reasonCodes: [
            'I123',
            'R567',
          ],
          score: 0.01,
          signals: {
            phone: {},
          },
        },
        customerProfile: {
          customerUserId: user.uuid,
        },
      }
    end

    let(:known_reason_codes) do
      {
        I123: 'Person is over seven feet tall.',
        R567: 'Person may be an armadillo.',
        R890: 'Help! I am trapped in a reason code factory!',
      }
    end

    before do
      known_reason_codes.each do |(code, description)|
        SocureReasonCode.create(code:, description:)
      end

      stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore')
        .to_return(
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(socure_response_body),
        )
    end

    context 'when document capture session result is present in redis' do
      let(:expected_event_body) do
        {
          user_id: user.uuid,
          phone_result: proofing_result.to_h.merge(vendor_workflow: nil),
          socure_result: {
            # attributes_requiring_additional_verification: [],
            # can_pass_with_additional_verification: false,
            errors: {},
            result: {
              name_phone_correlation: {
                reason_codes: {
                  'I123' => 'Person is over seven feet tall.',
                  'R567' => 'Person may be an armadillo.',
                  'R890' => 'Help! I am trapped in a reason code factory!',
                },
                score: 0.99,
              },
              phonerisk: {
                reason_codes: {
                  'I123' => 'Person is over seven feet tall.',
                  'R567' => 'Person may be an armadillo.',
                },
                score: 0.01,
              },
              customer_user_id: user.uuid,
            },
            exception: nil,
            reference:,
            success: true,
            transaction_id: reference,
            vendor_name: 'socure_phonerisk',
            timed_out: false,
          },
        }
      end

      it 'makes a proofing call' do
        expect(job.proofer(user: user)).to receive(:proof).and_call_original
        perform
      end

      it 'does not log an idv_socure_shadow_mode_proofing_result_missing event' do
        perform
        expect(analytics).not_to have_logged_event(:idv_socure_shadow_mode_proofing_result_missing)
      end

      it 'logs an event' do
        perform
        expect(analytics).to have_logged_event(
          :idv_socure_shadow_mode_phonerisk_result,
          expected_event_body,
        )
      end

      context 'when the user has an MFA phone number' do
        let(:applicant_pii) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
        end

        let(:encrypted_arguments) do
          Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
            JSON.generate({ applicant_pii: applicant_pii }),
          )
        end

        it 'logs an event with the phone number' do
          perform
          expect(analytics).to have_logged_event(
            :idv_socure_shadow_mode_phonerisk_result,
            expected_event_body,
          )
        end
      end

      context 'when socure proofer raises an error' do
        before do
          allow(job.proofer(user: user)).to receive(:proof).and_raise
        end

        it 'does not squash the error' do
          # If the Proofer encounters an error while _making_ a request, that
          # will be returned as a Result with the `exception` property set.
          # Other errors will be raised as normal.
          expect { perform }.to raise_error
        end
      end
    end

    context 'when document capture session result is not present in redis' do
      let(:document_capture_session_result_id) { 'some-id-that-is-not-valid' }

      it 'logs an idv_socure_shadow_mode_proofing_result_missing event' do
        perform

        expect(analytics).to have_logged_event(
          :idv_socure_shadow_mode_phonerisk_result_missing,
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

    context 'when an unknown reason code is encountered' do
      let(:socure_response_body) do
        {
          phoneRisk: {
            reasonCodes: ['I000'],
            score: 0.05,
            signals: {
              phone: {},
            },
          },
          namePhoneCorrelation: {
            reasonCodes: [],
            score: 0.95,
          },
        }
      end

      it 'still logs it' do
        perform
        expect(analytics).to have_logged_event(
          :idv_socure_shadow_mode_phonerisk_result,
          satisfy do |attributes|
            reason_codes = attributes.dig(:socure_result, :result, :phonerisk, :reason_codes)
            expect(reason_codes).to include(
              'I000' => '[unknown]',
            )
          end,
        )
      end
    end
  end

  describe '#build_applicant' do
    subject(:build_applicant) do
      job.build_applicant(encrypted_arguments:, user_email:)
    end

    let(:expected_attributes) do
      {
        first_name: 'FAKEY',
        last_name: 'MCFAKERSON',
        address1: '1 FAKE RD',
        address2: '',
        city: 'GREAT FALLS',
        state: 'MT',
        zipcode: '59010-1234',
        email: user.email,
        phone: '12025551212',
      }
    end

    context 'when the user has a phone directly passed in' do
      let(:applicant_pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
          phone: '12025551212',
        )
      end

      let(:encrypted_arguments) do
        Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
          JSON.generate({ applicant_pii: }),
        )
      end

      it 'builds an applicant structure with that phone number' do
        expect(build_applicant).to eql(
          expected_attributes.merge(phone: '12025551212'),
        )
      end
    end

    context 'when the user has a hybrid-handoff phone' do
      let(:applicant_pii_no_phone) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
          best_effort_phone_number_for_socure: {
            source: :hybrid_handoff,
            phone: '12025556789',
          },
        )
      end

      let(:encrypted_arguments) do
        Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
          JSON.generate({ applicant_pii: applicant_pii_no_phone }),
        )
      end

      it 'builds an applicant using the hybrid handoff number' do
        expect(build_applicant).to eql(
          expected_attributes.merge(
            phone: '12025556789',
            phone_source: 'hybrid_handoff',
          ),
        )
      end
    end

    context 'when no phone is available for the user' do
      it 'does not set phone at all' do
        expect(build_applicant).to eql(expected_attributes)
      end
    end
  end

  describe '#create_analytics' do
    it 'creates an Analytics instance with user and sp configured' do
      analytics = job.create_analytics(
        user:,
        service_provider_issuer: 'some-issuer',
      )
      expect(analytics.sp).to eql('some-issuer')
      expect(analytics.user).to eql(user)
    end
  end

  describe '#proofer' do
    it 'returns a configured proofer' do
      allow(IdentityConfig.store).to receive(:socure_idplus_api_key).and_return('an-api-key')
      allow(IdentityConfig.store).to receive(:socure_idplus_base_url).and_return('https://example.org')
      allow(IdentityConfig.store).to receive(:socure_idplus_timeout_in_seconds).and_return(6)

      expect(job.proofer(user:).config.to_h).to eql(
        user_uuid: user.uuid,
        user_email:,
        api_key: 'an-api-key',
        base_url: 'https://example.org',
        timeout: 6,
      )
    end
  end
end
