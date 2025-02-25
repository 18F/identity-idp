# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocAuth::Dos::Request do
  let(:full_url) { 'https://dos.example.test/mrz' }
  let(:http_method) { :get }
  let(:status) { 200 }
  let(:subject) { described_class.new }

  before do
    stub_request(http_method, full_url).to_return(status: status, body: '')
  end

  describe '#fetch' do
    context 'GET request' do
      let(:http_method) { :get }

      context 'with a successful http request' do
        let(:status) { 200 }

        it 'raises a NotImplementedError when attempting to handle the response' do
          expect { subject.fetch }.to raise_error(NotImplementedError)
        end
      end
    end
  end

  describe '#send_http_request' do
    context 'with an unsupported HTTP method' do
      let(:http_method) { 'PATCH' }
      before do
        allow(subject).to receive(:http_method).and_return(http_method)
      end

      it 'raises a NotImplementedError' do
        expect do
          subject.send(:send_http_request)
        end.to raise_error(NotImplementedError, "HTTP method #{http_method} not implemented")
      end
    end
  end

  describe 'unimplemented methods' do
    describe '#event_name' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:event_name) }.to raise_error(NotImplementedError)
      end
    end

    describe '#metric_name' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:metric_name) }.to raise_error(NotImplementedError)
      end
    end

    describe '#handle_http_response' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:handle_http_response, nil) }.to raise_error(NotImplementedError)
      end
    end

    describe '#endpoint' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:endpoint) }.to raise_error(NotImplementedError)
      end
    end

    describe '#request_headers' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:request_headers) }.to raise_error(NotImplementedError)
      end
    end

    describe '#body' do
      it 'raises a NotImplementedError' do
        expect { subject.send(:body) }.to raise_error(NotImplementedError)
      end
    end
  end
end
