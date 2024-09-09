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
  let(:user) { build(:user) }
  let(:results_id) { 'get this from the webhook request' }

  let(:config) do
    { api_key: }
  end

  subject(:request) do
    described_class.new(config:, results_id:)
  end

  xdescribe '#body' do
    it 'contains all expected values' do
      freeze_time do
        expect(JSON.parse(request.body, symbolize_names: true)).to eql(
          {
            some_key: 'ferd is a ferd',
          },
        )
      end
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

  xdescribe '#send_request' do
    before do
      stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
        to_return(
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(
            {
              another_key: 'yet more nonsense',
            },
          ),
        )
    end

    it 'includes API key' do
      request.send_request

      expect(WebMock).to have_requested(
                           :post, 'https://example.org/api/3.0/EmailAuthScore'
                         ).with(headers: { 'Authorization' => "SocureApiKey #{api_key}" })
    end

    it 'includes JSON serialized body' do
      request.send_request

      expect(WebMock).to have_requested(
                           :post, 'https://example.org/api/3.0/EmailAuthScore'
                         ).with(body: request.body)
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

    xcontext 'when service returns an HTTP 400 response' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
          to_return(
            status: 400,
            headers: {
              'Content-Type' => 'application/json',
            },
            body: JSON.generate(
              {
                status: 'Error',
                referenceId: 'a-big-unique-reference-id',
                data: {
                  parameters: ['firstName'],
                },
                msg: 'Request-specific error message goes here',
              },
            ),
          )
      end

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(
                 Proofing::Socure::IdPlus::RequestError,
                 'Request-specific error message goes here (400)',
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

    xcontext 'when service returns an HTTP 401 reponse' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
          to_return(
            status: 401,
            headers: {
              'Content-Type' => 'application/json',
            },
            body: JSON.generate(
              {
                status: 'Error',
                referenceId: 'a-big-unique-reference-id',
                msg: 'Request-specific error message goes here',
              },
            ),
          )
      end

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(
                 Proofing::Socure::IdPlus::RequestError,
                 'Request-specific error message goes here (401)',
               )
      end
    end

    xcontext 'when service returns weird HTTP 500 response' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
          to_return(
            status: 500,
            body: 'It works!',
          )
      end

      it 'raises RequestError' do
        expect do
          request.send_request
        end.to raise_error(Proofing::Socure::IdPlus::RequestError)
      end
    end

    xcontext 'when request times out' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
          to_timeout
      end

      it 'raises a ProofingTimeoutError' do
        expect { request.send_request }.to raise_error Proofing::TimeoutError
      end
    end

    xcontext 'when connection is reset' do
      before do
        stub_request(:post, 'https://example.org/api/3.0/EmailAuthScore').
          to_raise(Errno::ECONNRESET)
      end

      it 'raises a RequestError' do
        expect { request.send_request }.to raise_error Proofing::Socure::IdPlus::RequestError
      end
    end
  end
end
