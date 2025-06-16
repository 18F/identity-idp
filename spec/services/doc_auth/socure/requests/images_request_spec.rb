require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::ImagesRequest do
  let(:reference_id) { 'fake_reference_id' }
  let(:images_request_endpoint) do
    URI.join(
      IdentityConfig.store.socure_docv_images_request_endpoint,
      reference_id,
    ).to_s
  end

  subject(:images_request) { described_class.new(reference_id:) }
  let(:body) { DocAuthImageFixtures.zipped_files(reference_id:).to_s }
  let(:status) { 200 }
  let(:message) do
    [
      subject.class.name,
      'Unexpected HTTP response',
      status,
    ].join(' ')
  end

  let(:connection_error_attributes) do
    {
      success: false,
      errors: { network: true },
      exception: DocAuth::RequestError.new(message, status),
      extra: {
        vendor: 'Socure',
        vendor_status_code: nil,
        vendor_status_message: nil,
      }.compact,
    }
  end

  describe '#fetch' do
    before do
      stub_request(:post, images_request_endpoint)
        .to_return(
          status:,
          body:,
        )
    end

    it 'fetches from the correct url' do
      subject.fetch

      expect(WebMock).to have_requested(:post, images_request_endpoint)
        .with(body: {})
    end

    it 'creates an IdvImages object with the binary data' do
      response = subject.fetch

      expect(response.class).to eq(Idv::IdvImages)
      expect(response.images.first.value.class).to eq Idv::BinaryImage
    end

    context 'when the response is empty' do
      let(:body) { '' }

      it 'returns an error' do
        response = subject.fetch

        expect(response).to eq connection_error_attributes
      end
    end

    context 'we get a 403 back' do
      let(:fake_socure_response) { {} }
      let(:fake_socure_status) { 403 }

      it 'does not raise an exception' do
        expect { subject.fetch }.not_to raise_error
      end
    end

    context 'we get a 500 back' do
      let(:fake_socure_response) { {} }
      let(:fake_socure_status) { 500 }

      it 'does not raise an exception' do
        expect { subject.fetch }.not_to raise_error
      end
    end

    context 'with timeout exception' do
      let(:response) { nil }
      let(:response_status) { 403 }
      let(:faraday_connection_failed_exception) { Faraday::ConnectionFailed }

      before do
        stub_request(:post, images_request_endpoint).to_raise(faraday_connection_failed_exception)
      end
      it 'expect handle_connection_error method to be called' do
        result = subject.fetch
        expect(result[:success]).to eq(connection_error_attributes[:success])
        expect(result[:errors]).to eq(connection_error_attributes[:errors])
        expect(result[:exception]).to be_a Faraday::ConnectionFailed
        expect(result[:extra]).to eq(connection_error_attributes[:extra])
      end
    end
  end
end
