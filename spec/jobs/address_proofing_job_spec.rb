require 'rails_helper'

RSpec.describe AddressProofingJob, type: :job do
  let(:document_capture_session) { create(:document_capture_session, result_id: SecureRandom.hex) }
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: applicant_pii }.to_json,
    )
  end
  let(:service_provider) { create(:service_provider) }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: Faker::PhoneNumber.cell_phone,
    }
  end
  let(:trace_id) { SecureRandom.hex }
  let(:user_id) { document_capture_session.user_id }
  let(:address_vendor) { :mock }

  before do
    allow(IdentityConfig.store).to receive(:idv_address_primary_vendor).and_return(address_vendor)
  end
  describe '.perform_later' do
    it 'stores results' do
      AddressProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        issuer: service_provider.issuer,
        user_id:,
      )

      result = document_capture_session.load_proofing_result[:result]
      expect(result).to be_present
    end
  end

  describe '#perform' do
    let(:conversation_id) { SecureRandom.hex }
    let(:instance) { AddressProofingJob.new }
    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        issuer: service_provider.issuer,
        user_id:,
      )
    end

    context 'webmock lexisnexis vendor' do
      let(:address_vendor) { :lexis_nexis }
      before do
        stub_request(
          :post,
          'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
        ).to_return(
          body: {
            Status: {
              ConversationId: conversation_id,
              TransactionStatus: 'passed',
            },
          }.to_json,
        )

        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
        allow(IdentityConfig.store).to receive(:lexisnexis_account_id).and_return('abc123')
        allow(IdentityConfig.store).to receive(:lexisnexis_request_mode).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_username).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_password).and_return('aaa')
        allow(IdentityConfig.store).to receive(:lexisnexis_base_url).and_return('https://lexisnexis.example.com/')
        allow(IdentityConfig.store).to receive(:lexisnexis_phone_finder_workflow).and_return('aaa')
      end

      it 'runs' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        expect(result[:exception]).to be_nil
        expect(result[:errors]).to eq({})
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false
        expect(result[:vendor_name]).to eq('lexisnexis:phone_finder')
      end

      it 'adds cost data' do
        expect { perform }.to(change { SpCost.count }.by(1))

        sp_cost = SpCost.last
        expect(sp_cost.issuer).to eq(service_provider.issuer)
        expect(sp_cost.transaction_id).to eq(conversation_id)
        expect(sp_cost.cost_type).to eq('lexis_nexis_address')
      end
    end

    context 'webmock vendor socure' do
      let(:address_vendor) { :socure }
      let(:phonerisk_score) { 0.01 }
      let(:namephone_correlation_score) { 0.99 }
      before do
        stub_request(
          :post,
          'https://sandbox.socure.test/api/3.0/EmailAuthScore',
        ).to_return(
          body: {
            referenceId: conversation_id,
            phoneRisk: {
              score: phonerisk_score,
              reasonCodes: [],
            },
            namePhoneCorrelation: {
              score: namephone_correlation_score,
              reasonCodes: [],
            },
          }.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'passes proofing' do
        perform

        result = document_capture_session.load_proofing_result[:result]

        expect(result[:exception]).to be_nil
        expect(result[:errors]).to eq({})
        expect(result[:success]).to be true
        expect(result[:timed_out]).to be false
        expect(result[:vendor_name]).to eq('socure_phonerisk')
      end

      it 'adds cost data' do
        expect { perform }.to(change { SpCost.count }.by(1))

        sp_cost = SpCost.last
        expect(sp_cost.issuer).to eq(service_provider.issuer)
        expect(sp_cost.transaction_id).to eq(conversation_id)
        expect(sp_cost.cost_type).to eq('socure_address')
      end

      context 'high phonerisk score' do
        let(:phonerisk_score) { 0.99 }

        it 'fails proofing' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:exception]).to be_nil
          expect(result[:success]).to be false
          expect(result[:timed_out]).to be false
          expect(result[:vendor_name]).to eq('socure_phonerisk')
        end
      end
      context 'low name phone correlation score' do
        let(:namephone_correlation_score) { 0.01 }

        it 'fails proofing' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:exception]).to be_nil
          expect(result[:success]).to be false
          expect(result[:timed_out]).to be false
          expect(result[:vendor_name]).to eq('socure_phonerisk')
        end
      end
    end

    context 'mock proofer' do
      let(:address_vendor) { :mock }
      context 'with an unsuccessful response from the proofer' do
        let(:applicant_pii) do
          super().merge(
            phone: Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
          )
        end

        it 'returns a result' do
          perform

          result = document_capture_session.load_proofing_result[:result]

          expect(result[:success]).to eq(false)
        end

        it 'does not add cost data' do
          expect { perform }.not_to(change { SpCost.count })
        end
      end
    end

    context 'a stale job' do
      before { instance.enqueued_at = 10.minutes.ago }

      it 'bails and does not do any proofing' do
        expect(DocAuthRouter).to_not receive(:address_proofer)

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end
  end
end
