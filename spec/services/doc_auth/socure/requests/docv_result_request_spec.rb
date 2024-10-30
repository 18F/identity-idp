require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocvResultRequest do
  let(:document_capture_session_uuid) { 'fake uuid' }
  let(:biometric_comparison_required) { false }

  subject(:docv_result_request) do
    described_class.new(
      document_capture_session_uuid:,
      biometric_comparison_required: biometric_comparison_required,
    )
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.com/' }
    let(:fake_socure_api_endpoint) { 'https://fake-socure.com/api/3.0/EmailAuthScore' }
    let(:docv_transaction_token) { 'fake docv transaction token' }
    let(:user) { create(:user) }
    let(:document_capture_session) do
      DocumentCaptureSession.create(user:).tap do |dcs|
        dcs.socure_docv_transaction_token = docv_transaction_token
      end
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_idplus_base_url).
        and_return(fake_socure_endpoint)
      allow(DocumentCaptureSession).to receive(:find_by).and_return(document_capture_session)
      stub_request(:post, fake_socure_api_endpoint).to_raise(Faraday::ConnectionFailed)
    end

    context 'with timeout exception' do
      let(:fake_socure_response) { {} }
      let(:fake_socure_status) { 500 }

      it 'expect handle_connection_error method to be called' do
        connection_error_attributes = {
          http_response: nil,
          biometric_comparison_required: biometric_comparison_required,
        }
        failed_response = DocAuth::Socure::Responses::DocvResultResponse.new(
          **connection_error_attributes,
        )
        allow(DocAuth::Socure::Responses::DocvResultResponse).to
        receive(:new).with(**connection_error_attributes).
          and_return(failed_response)
        expect(docv_result_request.fetch).to eq(failed_response)
      end
    end
  end
end
