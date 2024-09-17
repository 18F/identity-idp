require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocumentRequest do
  let(:document_capture_session_uuid) { 'abc123' }
  let(:redirect_url) { 'https://somewhere.com' }

  subject(:document_request) do
    described_class.new(document_capture_session_uuid:, redirect_url:)
  end

  describe 'a new request' do
    it 'exists' do
      expect(document_request).to be
    end
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.com/' }
    let(:fake_socure_response) { { 'url' => redirect_url } }
    let(:expected_request_body) { { method: 'POST', url: redirect_url } }
    let(:fake_socure_status) { 200 }

    before do
      allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
        and_return(fake_socure_endpoint)
      stub_request(:post, fake_socure_endpoint).to_return(
        status: fake_socure_status,
        body: JSON.generate(fake_socure_response),
      )
    end

    it 'fetches from the correct url' do
      response = document_request.fetch

      expect(response).to eq(fake_socure_response)
    end

    context 'we get a 403 back' do
      let(:fake_socure_response) { {} }
      let(:fake_socure_status) { 403 }

      it 'does not raise an exception' do
        expect { document_request.fetch }.not_to raise_error
      end
    end

    context 'we get a 500 back' do
      let(:fake_socure_response) { {} }
      let(:fake_socure_status) { 500 }

      it 'does not raise an exception' do
        expect { document_request.fetch }.not_to raise_error
      end
    end
  end
end
