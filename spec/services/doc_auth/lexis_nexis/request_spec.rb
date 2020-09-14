require 'rails_helper'

describe DocAuth::LexisNexis::Request do
  let(:account_id) { 123 }
  let(:workflow) { 'test_workflow' }
  let(:base_url) { Figaro.env.lexisnexis_base_url }
  let(:path) { "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations" }
  let(:full_url) { base_url + path }

  before do
    allow(subject).to receive(:username).and_return('test_username')
    allow(subject).to receive(:password).and_return('test_password')
    allow(subject).to receive(:account_id).and_return(account_id)
    allow(subject).to receive(:workflow).and_return(workflow)
    allow(subject).to receive(:body).and_return('test_body')
    allow(subject).to receive(:method).and_return(http_method)

    stub_request(http_method, full_url).to_return(status: status, body: '')
  end

  describe '#fetch' do
    context 'GET request' do
      let(:http_method) { :get }

      context 'with a successful http request' do
        let(:status) { 200 }

        it 'raises a NotImplementedError when attempting to handle the response' do
          expect do
            subject.fetch
          end.to raise_error(NotImplementedError)
        end
      end

      context 'with an unsuccessful http request' do
        let(:status) { 500 }

        it 'returns a generic DocAuth::Response object' do
          response = subject.fetch

          expect(response.class).to eq(DocAuth::Response)
        end

        it 'includes information on the error' do
          response = subject.fetch
          expected_message = [
            subject.class.name,
            'Unexpected HTTP response',
            status,
          ].join(' ')

          expect(response.exception.message).to eq(expected_message)
        end
      end
    end

    context 'POST request' do
      let(:http_method) { :post }

      context 'with a successful http request' do
        let(:status) { 200 }

        it 'raises a NotImplementedError when attempting to handle the response' do
          expect do
            subject.fetch
          end.to raise_error(NotImplementedError)
        end
      end

      context 'with an unsuccessful http request' do
        let(:status) { 500 }

        it 'returns a generic DocAuth::Response object' do
          response = subject.fetch

          expect(response.class).to eq(DocAuth::Response)
        end

        it 'includes information on the error' do
          response = subject.fetch
          expected_message = [
            subject.class.name,
            'Unexpected HTTP response',
            status,
          ].join(' ')

          expect(response.exception.message).to eq(expected_message)
        end
      end
    end
  end
end
