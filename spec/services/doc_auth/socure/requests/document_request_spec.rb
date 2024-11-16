require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocumentRequest do
  let(:document_capture_session_uuid) { 'fake uuid' }
  let(:redirect_url) { 'https://idv.test' }
  let(:language) { :en }

  subject(:document_request) do
    described_class.new(
      redirect_url: redirect_url,
      language:,
    )
  end

  describe '#fetch' do
    let(:document_type) { 'license' }
    let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
    let(:fake_socure_document_capture_app_url) { 'https://verify.fake-socure.test/something' }
    let(:docv_transaction_token) { 'fake docv transaction token' }
    let(:fake_socure_response) do
      {
        referenceId: 'socure-reference-id',
        data: {
          eventId: 'socure-event-id',
          customerUserId: document_capture_session_uuid,
          docvTransactionToken: docv_transaction_token,
          qrCode: 'qr-code',
          url: fake_socure_document_capture_app_url,
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
            method: 'GET',
            url: redirect_url,
          },
          language: language,
        },
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
      document_request.fetch

      expect(WebMock).to have_requested(:post, fake_socure_endpoint).
        with(body: JSON.generate(expected_request_body))
    end

    it 'passes the response through' do
      response = document_request.fetch

      expect(response).to eq(fake_socure_response)
    end

    context 'when the language is Spanish' do
      let(:language) { :es }

      it 'includes the correct language in the request_body' do
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
    context 'with timeout exception' do
      let(:response) { nil }
      let(:response_status) { 403 }
      let(:faraday_connection_failed_exception) { Faraday::ConnectionFailed }

      before do
        stub_request(:post, fake_socure_endpoint).to_raise(faraday_connection_failed_exception)
      end
      it 'expect handle_connection_error method to be called' do
        connection_error_attributes = {
          success: false,
          errors: { network: true },
          exception: faraday_connection_failed_exception,
          extra: {
            vendor: 'Socure',
            vendor_status_code: nil,
            vendor_status_message: nil,
          }.compact,
        }
        result = document_request.fetch
        expect(result[:success]).to eq(connection_error_attributes[:success])
        expect(result[:errors]).to eq(connection_error_attributes[:errors])
        expect(result[:exception]).to be_a Faraday::ConnectionFailed
        expect(result[:extra]).to eq(connection_error_attributes[:extra])
      end
    end
  end
end
