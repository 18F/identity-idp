require 'rails_helper'

RSpec.describe IppAamvaProofingJob, type: :job do
  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, result_id: SecureRandom.hex, user:)
  end
  let(:service_provider) { create(:service_provider) }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      dob: '1970-01-01',
      state_id_number: 'D12345678',
      state_id_jurisdiction: 'VA',
    }
  end
  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: applicant_pii }.to_json,
    )
  end
  let(:trace_id) { SecureRandom.hex }
  let(:user_id) { user.id }
  let(:analytics_spy) { instance_double(Analytics) }

  describe '#perform' do
    let(:instance) { IppAamvaProofingJob.new }
    let(:aamva_proofer) { instance_double(Proofing::Resolution::Plugins::AamvaPlugin) }
    let(:aamva_result) do
      Proofing::StateIdResult.new(
        success: true,
        vendor_name: 'state_id:aamva',
        transaction_id: 'abc123',
        errors: {},
        verified_attributes: %i[ssn dob],
      )
    end

    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        user_id: user_id,
        service_provider_issuer: service_provider.issuer,
      )
    end

    before do
      stub_analytics
      allow(Proofing::Resolution::Plugins::AamvaPlugin).to receive(:new).and_return(aamva_proofer)
      allow(aamva_proofer).to receive(:call).and_return(aamva_result)
    end

    context 'when AAMVA verification succeeds' do
      before do
        allow(Analytics).to receive(:new).and_return(analytics_spy)
      end

      it 'stores a successful result' do
        perform

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result).to be_present

        result = proofing_result.result
        expect(result[:success]).to be true
        expect(result[:errors]).to eq({})
        expect(result[:vendor_name]).to eq('state_id:aamva')
        expect(result[:verified_attributes]).to match_array(['ssn', 'dob'])
      end

      it 'calls AAMVA proofer with correct parameters' do
        expect(aamva_proofer).to receive(:call).with(
          hash_including(
            applicant_pii: hash_including(
              applicant_pii.merge(
                uuid: user.uuid,
                uuid_prefix: service_provider.app_id,
              ),
            ),
            current_sp: service_provider,
            state_id_address_resolution_result: nil,
            ipp_enrollment_in_progress: true,
            doc_auth_flow: true,
            analytics: analytics_spy,
          ),
        )

        perform
      end
    end

    context 'when AAMVA verification fails' do
      let(:aamva_result) do
        Proofing::StateIdResult.new(
          success: false,
          vendor_name: 'state_id:aamva',
          transaction_id: 'abc123',
          errors: { failed: true },
        )
      end

      it 'stores a failed result' do
        perform

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result).to be_present

        result = proofing_result.result
        expect(result[:success]).to be false
        expect(result[:errors][:failed]).to eq(true)
        expect(result[:vendor_name]).to eq('state_id:aamva')
        expect(result[:verified_attributes]).to be_empty
      end
    end

    context 'when user is not found' do
      let(:user_id) { 999999 }

      it 'raises an error' do
        expect { perform }.to raise_error(ArgumentError, 'User not found')
      end
    end

    context 'when AAMVA verification times out' do
      let(:aamva_result) do
        Proofing::StateIdResult.new(
          success: false,
          vendor_name: 'state_id:aamva',
          transaction_id: 'abc123',
          errors: { timeout: true },
          exception: Proofing::TimeoutError.new('AAMVA request timed out'),
        )
      end

      it 'stores the failed result' do
        perform

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result).to be_present

        result = proofing_result.result
        expect(result[:success]).to be false
      end
    end

    context 'when AAMVA verification has MVA exception' do
      let(:aamva_result) do
        Proofing::StateIdResult.new(
          success: false,
          vendor_name: 'state_id:aamva',
          transaction_id: 'abc123',
          errors: { exception: true },
          exception: Proofing::Aamva::VerificationError.new('MVA service unavailable'),
        )
      end

      it 'stores the failed result' do
        perform

        proofing_result = document_capture_session.load_proofing_result
        expect(proofing_result).to be_present

        result = proofing_result.result
        expect(result[:success]).to be false
      end
    end
  end
end
