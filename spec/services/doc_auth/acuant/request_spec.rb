require 'rails_helper'

describe DocAuth::Acuant::Request do
  let(:path) { '/test/path' }
  let(:full_url) { URI.join(Figaro.env.acuant_assure_id_url, path) }
  let(:request_body) { 'test request body' }
  let(:request_headers) do
    username = Figaro.env.acuant_assure_id_username
    password = Figaro.env.acuant_assure_id_password
    {
      'Authorization' => [
        'Basic',
        Base64.strict_encode64("#{username}:#{password}"),
      ].join(' '),
      'Accept' => 'application/json',
    }
  end
  let(:request_method) { :get }

  subject do
    request = described_class.new
    allow(request).to receive(:path).and_return(path)
    allow(request).to receive(:body).and_return(request_body)
    allow(request).to receive(:method).and_return(request_method)
    request
  end

  describe '#fetch' do
    context 'when the request resolves with a 200' do
      it 'calls handle_http_response on the subclass' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response.body.upcase
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request is a post instead of a get' do
      let(:request_method) { :post }

      it 'sends a post request with a request body' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response.body.upcase
        end

        stub_request(:post, full_url).
          with(headers: request_headers, body: request_body).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request resolves with a non 200 status' do
      it 'returns a response with an exception' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 404)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(network: I18n.t('errors.doc_auth.acuant_network_error'))
        expect(response.exception.message).to eq(
          'DocAuth::Acuant::Request Unexpected HTTP response 404',
        )
      end
    end

    context 'when the request resolves with retriable error then succeeds it only retries once' do
      it 'calls New Relic notice_error each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 200 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, hash_including(:custom_params)).once

        response = subject.fetch

        expect(response.success?).to eq(true)
      end
    end

    context 'when the request resolves with a 404 status it retries' do
      it 'calls New Relic notice_error each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 404 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(RuntimeError).once

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, hash_including(:custom_params)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request resolves with a 438 status it retries' do
      it 'calls New Relic notice_error each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 438 },
            { body: 'test response body', status: 438 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(RuntimeError).once

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, hash_including(:custom_params)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request resolves with a 438 status it retries' do
      it 'calls New Relic notice_error each retry' do
        allow(subject).to receive(:handle_http_response) do |http_response|
          http_response
        end

        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 439 },
            { body: 'test response body', status: 439 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(RuntimeError).once

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, hash_including(:custom_params)).twice

        response = subject.fetch

        expect(response.success?).to eq(false)
      end
    end

    context 'when the request times out' do
      it 'returns a response with a timeout message and exception and notifies NewRelic' do
        stub_request(:get, full_url).to_timeout

        expect(NewRelic::Agent).to receive(:notice_error)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(network: I18n.t('errors.doc_auth.acuant_network_error'))
        expect(response.exception).to be_a(Faraday::ConnectionFailed)
      end
    end
  end
end
