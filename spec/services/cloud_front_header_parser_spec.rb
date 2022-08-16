require 'rails_helper'

RSpec.describe CloudFrontHeaderParser do
  let(:url) { 'http://example.com' }
  let(:req) { Rack::Request.new(Rack::MockRequest.env_for(url, remote_addr_header)) }
  let(:port) { '1234' }
  subject { described_class.new(req) }

  context 'with an IPv4 address' do
    let(:ip) { '192.0.2.1' }
    let(:remote_addr_header) do
      { 'REMOTE_ADDR' => ip }
    end

    before do
      req.add_header('CloudFront-Viewer-Address', "#{ip}:#{port}")
    end

    describe '#client_ip' do
      it 'returns the IPv4 address' do
        expect(subject.client_ip).to eq ip
      end
    end

    describe '#client_port' do
      it 'returns the client port number' do
        expect(subject.client_port).to eq port
      end
    end
  end

  context 'with an IPv6 address' do
    let(:ip) { '[2001:DB8::1]' }
    let(:remote_addr_header) do
      { 'REMOTE_ADDR' => ip }
    end

    before do
      req.add_header('CloudFront-Viewer-Address', "#{ip}:#{port}")
    end

    describe '#client_ip' do
      it 'returns the bracketed IPv6 address' do
        expect(subject.client_ip).to eq ip
      end
    end

    describe '#client_port' do
      it 'returns the client port number' do
        expect(subject.client_port).to eq port
      end
    end
  end
end
