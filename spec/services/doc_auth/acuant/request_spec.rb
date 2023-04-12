require 'rails_helper'

RSpec.describe DocAuth::Acuant::Request do
  class SimpleAcuantRequest < DocAuth::Acuant::Request
    def handle_http_response(http_response)
      http_response.body.upcase!
      http_response
    end
  end

  let(:assure_id_url) { 'https://acuant.assureid.example.com' }
  let(:assure_id_username) { 'acuant.username' }
  let(:assure_id_password) { 'acuant.password' }

  let(:path) { '/test/path' }
  let(:full_url) { URI.join(assure_id_url, path) }
  let(:metric_name) { 'acuant' }
  let(:request_body) { 'test request body' }
  let(:request_headers) do
    username = assure_id_username
    password = assure_id_password
    {
      'Authorization' => [
        'Basic',
        Base64.strict_encode64("#{username}:#{password}"),
      ].join(' '),
      'Accept' => 'application/json',
    }
  end
  let(:request_method) { :get }

  let(:config) do
    DocAuth::Acuant::Config.new(
      assure_id_url: assure_id_url,
      assure_id_username: assure_id_username,
      assure_id_password: assure_id_password,
    )
  end

  subject do
    request = SimpleAcuantRequest.new(config: config)
    allow(request).to receive(:path).and_return(path)
    allow(request).to receive(:body).and_return(request_body)
    allow(request).to receive(:method).and_return(request_method)
    allow(request).to receive(:metric_name).and_return(metric_name)
    request
  end

  describe '#fetch' do
    context 'when the request resolves with a 200' do
      it 'calls handle_http_response on the subclass' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response.body).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request is a post instead of a get' do
      let(:request_method) { :post }

      it 'sends a post request with a request body' do
        stub_request(:post, full_url).
          with(headers: request_headers, body: request_body).
          to_return(body: 'test response body', status: 200)

        response = subject.fetch

        expect(response.body).to eq('TEST RESPONSE BODY')
      end
    end

    context 'when the request resolves with a non 200 status' do
      it 'returns a response with an exception' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 404)
        allow(NewRelic::Agent).to receive(:notice_error)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(network: true)
        expect(response.exception.message).to include('Unexpected HTTP response 404')
      end
    end

    context 'when the request resolves with retriable error then succeeds it only retries once' do
      it 'calls NewRelic::Agent.notice_error each retry' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 200 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, { custom_params: hash_including(:retry) }).once

        response = subject.fetch

        expect(response.success?).to eq(true)
      end
    end

    context 'when the request resolves with a 404 status it retries' do
      it 'calls NewRelic::Agent.notice_error each retry' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(
            { body: 'test response body', status: 404 },
            { body: 'test response body', status: 404 },
          )

        expect(NewRelic::Agent).to receive(:notice_error).
          with(DocAuth::RequestError, {}).once

        expect(NewRelic::Agent).to receive(:notice_error).
          with(anything, { custom_params: hash_including(:retry) }).twice

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
        expect(response.errors).to eq(network: true)
        expect(response.exception).to be_a(Faraday::ConnectionFailed)
        expect(response.extra).to include(vendor: 'Acuant')
      end
    end

    context 'when the request resolves with a handled http error status' do
      def expect_failed_response(response)
        expect(response.success?).to eq(false)
        expect(response.exception).to be_kind_of(DocAuth::RequestError)
        expect(response.exception.message).not_to be_empty
      end

      it 'it produces a 438 error' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 438)

        expect(NewRelic::Agent).not_to receive(:notice_error)

        response = subject.fetch

        expect_failed_response(response)
        expect(response.errors).to eq(general: [DocAuth::Errors::IMAGE_LOAD_FAILURE])
        expect(response.extra).to include(vendor: 'Acuant')
      end

      it 'it produces a 439 error' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 439)

        expect(NewRelic::Agent).not_to receive(:notice_error)

        response = subject.fetch

        expect_failed_response(response)
        expect(response.errors).to eq(general: [DocAuth::Errors::PIXEL_DEPTH_FAILURE])
        expect(response.extra).to include(vendor: 'Acuant')
      end

      it 'it produces a 440 error' do
        stub_request(:get, full_url).
          with(headers: request_headers).
          to_return(body: 'test response body', status: 440)

        expect(NewRelic::Agent).not_to receive(:notice_error)

        response = subject.fetch

        expect_failed_response(response)
        expect(response.errors).to eq(general: [DocAuth::Errors::IMAGE_SIZE_FAILURE])
        expect(response.extra).to include(vendor: 'Acuant')
      end
    end
  end
end
