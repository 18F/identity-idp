# frozen_string_literal: true

require 'rails_helper'

MrzResponse = Struct.new(:body, :status, :success?)

RSpec.describe DocAuth::Dos::Requests::MrzRequest do
  let(:mrz_endpoint) { 'https://dos.example.test/mrz' }
  let(:client_id) { 'client_id' }
  let(:client_secret) { 'client_secret' }
  let(:mrz) { '1234567890' }
  let(:correlation_id) { '1234567890' }
  let(:subject) do
    described_class.new(mrz: mrz)
  end
  let(:mrz_result) { 'YES' }
  let(:response_body) { { response: mrz_result }.to_json }
  let(:response_headers) do
    {
      'Content-Type' => 'application/json',
      'X-Correlation-ID' => correlation_id,
    }
  end
  let(:http_status) { 200 }

  before do
    allow(IdentityConfig.store).to receive(:dos_passport_mrz_endpoint).and_return(mrz_endpoint)
    allow(IdentityConfig.store).to receive(:dos_passport_client_id).and_return(client_id)
    allow(IdentityConfig.store).to receive(:dos_passport_client_secret).and_return(client_secret)
    allow(SecureRandom).to receive(:uuid).and_return(correlation_id)
    stub_request(:post, mrz_endpoint)
      .with(
        body: "{\"mrz\":\"#{mrz}\",\"category\":\"book\"}",
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Client-Id' => client_id,
          'Client-Secret' => client_secret,
          'Content-Type' => 'application/json',
          'X-Correlation-ID' => correlation_id,
          'User-Agent' => 'Faraday v2.12.2',
        },
      )
      .to_return(status: http_status, body: response_body, headers: response_headers)
  end

  context 'when the MRZ matches' do
    it 'succeeds' do
      response = subject.fetch
      expect(response.success?).to be(true)
      expect(response.extra).to include(
        vendor: 'DoS',
        correlation_id_sent: correlation_id,
        correlation_id_received: correlation_id,
      )
    end
  end

  context "when the MRZ doesn't match" do
    let(:mrz_result) { 'NO' }

    it 'fails' do
      response = subject.fetch
      expect(response.success?).to be(false)
      expect(response.extra).to include(
        vendor: 'DoS',
        correlation_id_sent: correlation_id,
        correlation_id_received: correlation_id,
      )
    end
  end

  context "when the response is neither 'YES' nor 'NO'" do
    let(:mrz_result) { 'MAYBE' }

    it 'fails with a message' do
      response = subject.fetch
      expect(response.success?).to be(false)
      expect(response.extra).to include(
        vendor: 'DoS',
        correlation_id_sent: correlation_id,
        correlation_id_received: correlation_id,
      )
      expect(response.errors).to include(message: "Unexpected response: #{mrz_result}")
    end
  end

  context 'when the request fails' do
    let(:http_status) { 401 }

    context 'when the response error is a hash' do
      let(:response_body) do
        { error: { code: 'ERR', message: 'issues @ State', reason: 'just because' } }.to_json
      end

      it 'handles the nested error without throwing an exception' do
        response = subject.fetch
        expect(response.success?).to be(false)
        expect(response.errors).to include(network: true)
        expect(response.extra).to include(
          vendor: 'DoS',
          error_code: 'ERR',
          error_message: 'issues @ State',
          error_reason: 'just because',
          correlation_id_sent: correlation_id,
          correlation_id_received: correlation_id,
        )
      end
    end

    context 'when the response error is a string' do
      let(:response_body) do
        { error: 'Authentication denied.' }.to_json
      end

      it 'handles the string error without throwing an exception' do
        response = subject.fetch
        expect(response.success?).to be(false)
        expect(response.errors).to include(network: true)
        expect(response.extra).to include(
          vendor: 'DoS',
          error_code: nil,
          error_message: 'Authentication denied.',
          error_reason: nil,
          correlation_id_sent: correlation_id,
          correlation_id_received: correlation_id,
        )
      end
    end

    context 'when the response error is empty' do
      let(:response_body) { '' }

      it 'handles empty response gracefully' do
        response = subject.fetch
        expect(response.success?).to be(false)
        expect(response.errors).to include(network: true)
        expect(response.extra).to include(
          vendor: 'DoS',
          error_code: nil,
          error_message: nil,
          error_reason: nil,
          correlation_id_sent: correlation_id,
          correlation_id_received: correlation_id,
        )
      end
    end
  end
end
