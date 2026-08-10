require 'rails_helper'

RSpec.describe Proofing::Clear1::Request do
  subject(:request) { described_class.new }

  let(:idv_clear1_api_key) { 'a-valid-api-key' }

  before do
    allow(IdentityConfig.store).to receive(:idv_clear1_api_key).and_return(idv_clear1_api_key)
  end

  describe 'a new request' do
    it 'exists' do
      expect(request).to be
    end
  end

  describe '#fetch' do
    let(:fake_clear1_endpoint) { 'https://clear1.test/' }
    let(:fake_metric_name) { 'fake metric' }

    before do
      allow(request).to receive(:endpoint).and_return(fake_clear1_endpoint)
      allow(request).to receive(:metric_name).and_return(fake_metric_name)

      stub_request(:get, fake_clear1_endpoint)
        .with(headers: {
          'Content-Type': 'application/json',
          Authorization: "Bearer #{idv_clear1_api_key}",
        })
        .to_return(
          status: response_status,
          body: response,
        )
    end

    context 'with a valid response' do
      let(:response) { { token: 'valid_token' }.to_json }
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
      let(:response) { nil }
      let(:response_status) { 403 }

      let(:exception_msg) do
        [
          described_class.name,
          'Unexpected HTTP response',
          response_status,
        ].join(' ')
      end

      it 'returns the expected error' do
        result = request.fetch
        expect(result.success?).to eq false
        expect(result.errors).to eq({ network: true, clear1: true })
        expect(result.extra).to eq(
          {
            vendor_name: Idp::Constants::Vendors::CLEAR1,
            exception: Proofing::Clear1::Request::RequestError.new(exception_msg, status),
          },
        )
      end
    end
  end
end
