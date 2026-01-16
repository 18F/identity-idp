require 'rails_helper'

RSpec.describe DocAuth::Socure::Request do
  subject(:request) { described_class.new }

  describe 'a new request' do
    it 'exists' do
      expect(request).to be
    end
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
    let(:fake_metric_name) { 'fake metric' }

    before do
      allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
        .and_return(fake_socure_endpoint)
      allow(request).to receive(:endpoint).and_return(fake_socure_endpoint)
      allow(request).to receive(:metric_name).and_return(fake_metric_name)

      stub_request(:get, fake_socure_endpoint).to_return(
        status: response_status,
        body: response,
      )
    end

    context 'with a valid response' do
      let(:response) { JSON.generate({ 'url' => 'https://localhost' }) }
      let(:response_status) { 200 }

      # Because we have not implemented
      # `#handle_http_response`. Remove when we do.
      it 'raises a NotImplementedError' do
        expect { request.fetch }.to raise_error NotImplementedError
      end
    end

    context 'with no body in the response' do
      let(:status) { 'timeout' }
      let(:msg) { 'error message' }
      let(:reference_id) { 'fake_reference_id' }
      let(:response) do
        {
          status:,
          msg:,
          referenceId: reference_id,
        }.to_json
      end
      let(:response_status) { 403 }

      let(:exception_msg) do
        [
          described_class.name,
          'Unexpected HTTP response',
          response_status,
        ].join(' ')
      end
      let(:expected_error) do
        {
          success: false,
          errors: { network: true },
          exception: DocAuth::RequestError.new(exception_msg, status),
          extra: {
            vendor: 'Socure',
            vendor_status: status,
            vendor_status_message: msg,
            reference_id:,
          }.compact,
        }
      end

      it 'returns the expected error' do
        expect(request.fetch).to eq expected_error
      end
    end
  end
end
