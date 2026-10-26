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

  describe '#ja3_fingerprint' do
    context 'with the JA3 header sent' do
      before do
        req.headers['CloudFront-Viewer-JA3-Fingerprint'] = 'e7d705a3286e19ea42f587b344ee6865'
      end

      it 'returns the JA3 fingerprint' do
        expect(subject.ja3_fingerprint).to eq('e7d705a3286e19ea42f587b344ee6865')
      end
    end

    context 'with no JA3 header sent' do
      it 'returns nil' do
        expect(subject.ja3_fingerprint).to be nil
      end
    end
  end

  describe '#ja4_fingerprint' do
    context 'with the JA4 header sent' do
      before do
        req.headers['CloudFront-Viewer-JA4-Fingerprint'] =
          't13d1516h2_8daaf6152771_b186095e22b6'
      end

      it 'returns the JA4 fingerprint' do
        expect(subject.ja4_fingerprint).to eq('t13d1516h2_8daaf6152771_b186095e22b6')
      end
    end

    context 'with no JA4 header sent' do
      it 'returns nil' do
        expect(subject.ja4_fingerprint).to be nil
      end
    end
  end

  context 'with no CloudFront header sent' do
    let(:ip) { '192.0.2.1' }

    describe '#client_port' do
      it 'returns nil' do
        expect(subject.client_port).to be nil
      end
    end
  end

  context 'with no request included' do
    let(:req) { nil }

    describe '#viewer_address' do
      it 'returns nil' do
        expect(subject.viewer_address).to be nil
      end
    end

    describe '#client_port' do
      it 'returns nil' do
        expect(subject.client_port).to be nil
      end
    end

    describe '#ja3_fingerprint' do
      it 'returns nil' do
        expect(subject.ja3_fingerprint).to be nil
      end
    end

    describe '#ja4_fingerprint' do
      it 'returns nil' do
        expect(subject.ja4_fingerprint).to be nil
      end
    end
  end
end
