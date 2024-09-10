require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::FetchResultsRequest do
  let(:config) do
    Proofing::Socure::IdPlus::Config.new(
      api_key:,
      base_url:,
      timeout:,
    )
  end
  let(:api_key) { 'super-$ecret' }
  let(:base_url) { 'https://example.org/' }
  let(:timeout) { 5 }
  let(:reference_id) { 'get this from the webhook request' }

  let(:config) do
    {
      api_key:,
      base_url:
    }
  end

  subject(:request) do
    described_class.new(config:, reference_id:)
  end

  describe '#body' do
    it 'is empty' do
      expect(JSON.parse(request.body, symbolize_names: true)).to eql({})
    end
  end

  describe '#headers' do
    it 'includes appropriate Content-Type header' do
      expect(request.headers).to include('Content-Type' => 'application/json')
    end

    it 'includes appropriate Authorization header' do
      expect(request.headers).to include('Authorization' => "SocureApiKey #{api_key}")
    end
  end

  describe '#send_request' do
    let(:body) { {} }
    let(:response_status) { 200 }

    before do
      stub_request(:post, "https://example.org/api/3.0/transaction?referenceId=#{reference_id}").
        to_return(
          status: response_status,
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(body),
        )
    end

    it 'makes the request with the API key and reference id' do
      request.send_request

      expect(WebMock).to have_requested(
        :post, "https://example.org/api/3.0/transaction?referenceId=#{reference_id}"
      ).with(headers: { 'Authorization' => "SocureApiKey #{api_key}" })
    end

    xcontext 'when service returns HTTP 200 response' do
      it 'method returns a Proofing::Socure::IdPlus::Response' do
        res = request.send_request
        expect(res).to be_a(Proofing::Socure::IdPlus::Response)
      end

      xit 'check: do we need this? - response has kyc data' do
        res = request.send_request
        expect(res.kyc_field_validations).to be
        expect(res.kyc_reason_codes).to be
      end
    end

    context 'when service returns an HTTP 400 response' do
      let(:response_status) { 400 }
      let(:body) do
        {
          status: 'Error',
          referenceId: 'a-different-unique-reference-id',
          msg: 'Another request-specific error message goes here',
        }
      end

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::RequestError,
          'Another request-specific error message goes here (400)',
        )
      end

      it 'includes reference_id on RequestError' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::RequestError,
        ) do |err|
          expect(err.reference_id).to eql('a-different-unique-reference-id')
        end
      end
    end

    context 'when service returns an HTTP 401 response' do
      let(:response_status) { 401 }
      let(:body) do
        {
          status: 'Error',
          referenceId: 'a-big-unique-reference-id',
          msg: 'Request-specific error message goes here',
        }
      end

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::RequestError,
          'Request-specific error message goes here (401)',
        )
      end

      it 'includes reference_id on RequestError' do
        expect do
          request.send_request
        end.to raise_error(
          Proofing::Socure::IdPlus::RequestError,
        ) do |err|
          expect(err.reference_id).to eql('a-big-unique-reference-id')
        end
      end
    end

    context 'when service returns weird HTTP 500 response' do
      let(:response_status) { 500 }

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(Proofing::Socure::IdPlus::RequestError)
      end
    end

    context 'when request times out' do
      before do
        stub_request(:post, "https://example.org/api/3.0/transaction?referenceId=#{reference_id}").
          to_timeout
      end

      it 'raises a ProofingTimeoutError' do
        expect { request.send_request }.to raise_error Proofing::TimeoutError
      end
    end

    context 'when connection is reset' do
      before do
        stub_request(:post, "https://example.org/api/3.0/transaction?referenceId=#{reference_id}").
          to_raise(Errno::ECONNRESET)
      end

      it 'raises a RequestError' do
        expect { request.send_request }.to raise_error Proofing::Socure::IdPlus::RequestError
      end
    end
  end
end
