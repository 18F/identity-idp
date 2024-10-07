require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocumentRequest do
  let(:document_capture_session_uuid) { 'abc123' }
  let(:redirect_url) { 'https://somewhere.com' }
  let(:language) { :en }

  subject(:document_request) do
    described_class.new(document_capture_session_uuid:, redirect_url:, language:)
  end

  describe 'a new request' do
    it 'exists' do
      expect(document_request).to be
    end
  end

  describe '#fetch' do
    let(:language) { :en }
    let(:document_type) { 'license' }
    let(:fake_socure_endpoint) { 'https://fake-socure.com/' }
    let(:socure_document_capture_url) { 'https://verify.socure.us/something' }
    let(:docv_transaction_token) { 'docv transaction token' }
    let(:fake_socure_response) do
      {
        referenceId: 'socure-reference-id',
        data: {
          eventId: 'socure-event-id',
          customerUserId: document_capture_session_uuid,
          docvTransactionToken: docv_transaction_token,
          qrCode: 'data:image/png;base64,iVBO......K5CYII=',
          url: socure_document_capture_url,
        },
      }
    end

    let(:expected_request_body) do
      {
        config:
        {
          documentType: document_type,
          redirect:
          {
            method: 'POST',
            url: redirect_url,
          },
          language: language,
        },
        customerUserId: document_capture_session_uuid,
      }
    end
    let(:fake_socure_status) { 200 }

    before do
      allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
        and_return(fake_socure_endpoint)
      stub_request(:post, fake_socure_endpoint).
        to_return(
          status: fake_socure_status,
          body: JSON.generate(fake_socure_response),
        )
    end

    it 'fetches from the correct url' do
      response = document_request.fetch

      expect(WebMock).to have_requested(:post, fake_socure_endpoint).
        with(body: JSON.generate(expected_request_body))

      expect(response.dig('data', 'url')).to eq(socure_document_capture_url)
      expect(response.dig('data', 'docvTransactionToken')).to eq(docv_transaction_token)
    end

    context 'when the language is Spanish' do
      let(:language) { :es }

      it 'fetches from the correct url' do
        document_request.fetch

        expect(WebMock).to have_requested(:post, fake_socure_endpoint).
          with(body: JSON.generate(expected_request_body))
      end
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
