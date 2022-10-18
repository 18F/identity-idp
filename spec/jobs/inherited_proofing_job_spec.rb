require 'rails_helper'

RSpec.describe InheritedProofingJob, type: :job do
  include Idv::InheritedProofing::ServiceProviderServices
  include_context 'va_api_context'

  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }
  let(:va_inherited_proofing_auth_code) { auth_code }

  before do
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    allow_any_instance_of(Idv::InheritedProofing::ServiceProviderServices).to \
      receive(:va_inherited_proofing?).and_return true
  end

  describe '#perform' do
    it 'calls api for user data and stores in document capture session' do
      document_capture_session.create_doc_auth_session

      InheritedProofingJob.perform_now(
        inherited_proofing_service_provider_id,
        inherited_proofing_service_provider_data, document_capture_session.uuid
      )

      result = document_capture_session.load_proofing_result[:result]

      expect(result).to be_present
      expect(result).to include(last_name: 'Fakerson')
    end
  end
end
