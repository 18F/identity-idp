require 'rails_helper'

RSpec.describe CloudFrontHeaderParser do
  let(:req) { ActionDispatch::TestRequest.new({}) }
  let(:port) { '1234' }

  subject { described_class.new(req) }

  context 'with an IPv4 address' do
    let(:ip) { '192.0.2.1' }

    before do
      req.headers['CloudFront-Viewer-Address'] = "#{ip}:#{port}"
    end

    describe '#client_port' do
      it 'returns the client port number' do
        expect(subject.client_port).to eq port
      end
    end
  end

  context 'with an IPv6 address' do
    let(:ip) { '[2001:DB8::1]' }

    before do
      req.headers['CloudFront-Viewer-Address'] = "#{ip}:#{port}"
    end

    describe '#client_port' do
      it 'returns the client port number' do
        expect(subject.client_port).to eq port
      end
    end
  end

  context 'with no CloudFront header sent' do
    let(:ip) { '192.0.2.1' }

    describe '#client_port' do
      it 'returns nil' do
        expect(subject.client_port).to eq nil
      end
    end
  end
end
