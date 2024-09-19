require 'rails_helper'

RSpec.describe DocAuth::Socure::Request do
  subject(:request) { described_class.new }

  describe 'a new request' do
    it 'exists' do
      expect(request).to be
    end
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.com/' }
    let(:fake_metric_name) { 'fake metric' }

    before do
      allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
        and_return(fake_socure_endpoint)
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

      it 'raises a NotImplementedError' do
        expect { request.fetch }.to raise_error NotImplementedError
      end
    end

    context 'with no body in the response' do
      let(:response) { nil }
      let(:response_status) { 403 }

      it 'returns {}' do
        expect(request.fetch).to eq({})
      end
    end
  end
end
