# frozen_string_literal: true

require 'rails_helper'

MrzResponse = Struct.new(:body, :status, :success?)

RSpec.describe DocAuth::Dos::Requests::MrzRequest do
  let(:mrz_endpoint) { 'https://dos.example.test/mrz' }
  let(:client_id) { 'client_id' }
  let(:client_secret) { 'client_secret' }
  let(:mrz) { '1234567890' }
  let(:request_id) { '1234567890' }
  let(:subject) do
    described_class.new(request_id: request_id, mrz: mrz)
  end
  let(:mrz_result) { 'YES' }
  let(:response_body) { { response: mrz_result }.to_json }
  let(:http_status) { 200 }

  before do
    allow(IdentityConfig.store).to receive(:dos_passport_mrz_endpoint).and_return(mrz_endpoint)
    allow(IdentityConfig.store).to receive(:dos_passport_client_id).and_return(client_id)
    allow(IdentityConfig.store).to receive(:dos_passport_client_secret).and_return(client_secret)
    stub_request(:post, mrz_endpoint)
      .with(
        body: "{\"mrz\":\"#{mrz}\",\"category\":\"book\"}",
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Client-Id' => client_id,
          'Client-Secret' => client_secret,
          'Content-Type' => 'application/json',
          'X-Correlation-ID' => request_id,
          'User-Agent' => 'Faraday v2.12.2',
        },
      )
      .to_return(status: http_status, body: response_body, headers: {})
  end

  context 'when the MRZ matches' do
    it 'succeeds' do
      expect(subject.fetch.success?).to be(true)
    end
  end

  context "when the MRZ doesn't match" do
    let(:mrz_result) { 'NO' }

    it 'fails' do
      expect(subject.fetch.success?).to be(false)
    end
  end

  context "when the response is neither 'YES' nor 'NO'" do
    let(:mrz_result) { 'MAYBE' }

    it 'fails with a message' do
      expect(subject.fetch.success?).to be(false)
      expect(subject.fetch.errors).to include(message: "Unexpected response: #{mrz_result}")
    end
  end

  context 'when the request fails' do
    let(:http_status) { 500 }
    let(:response_body) { { status: { code: 'ERR', message: 'issues @ State' } }.to_json }

    it 'fails with a message' do
      expect(subject.fetch.success?).to be(false)
      expect(subject.fetch.errors).to include(network: true)
      expect(subject.fetch.extra).to include(
        vendor: 'DoS',
        vendor_status_code: 'ERR',
        vendor_status_message: 'issues @ State',
        request_id: request_id,
      )
    end
  end
end
