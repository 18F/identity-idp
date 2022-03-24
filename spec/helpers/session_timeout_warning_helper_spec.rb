require 'rails_helper'

describe SessionTimeoutWarningHelper do
  describe '#expires_at' do
    around do |ex|
      freeze_time { ex.run }
    end

    it 'returns time before now' do
      expect(helper.expires_at).to be < Time.zone.now
    end

    context 'with session expiration' do
      before do
        allow(helper).to receive(:session).and_return(session_expires_at: Time.zone.now + 1)
      end

      it 'returns time remaining in user session' do
        expect(helper.expires_at).to be > Time.zone.now
      end
    end
  end

  def time_between_warning_and_timeout
    IdentityConfig.store.session_timeout_warning_seconds
  end

  describe '#timeout_refresh_path' do
    let(:http_host) { 'example.com' }
    before do
      allow(helper).to receive(:request).and_return(
        ActionDispatch::Request.new(
          'HTTP_HOST' => http_host,
          'PATH_INFO' => path_info,
          'rack.url_scheme' => 'https',
        ),
      )
    end

    context 'with no params in the request url' do
      let(:path_info) { '/foo/bar' }

      it 'adds timeout=true params' do
        expect(helper.timeout_refresh_path).to eq('/foo/bar?timeout=true')
      end
    end

    context 'with params in the request url' do
      let(:path_info) { '/foo/bar?key=value' }

      it 'adds timeout=true and preserves params' do
        expect(helper.timeout_refresh_path).to eq('/foo/bar?key=value&timeout=true')
      end
    end

    context 'with timeout=true and request_id=123 \
            in the query params already' do
      let(:path_info) { '/foo/bar?timeout=true&request_id=123' }

      it 'is the same' do
        expect(helper.timeout_refresh_path).to eq('/foo/bar?request_id=123&timeout=true')
      end
    end

    context 'with a malicious host value' do
      let(:path_info) { '/foo/bar' }
      let(:http_host) { "mTpvPME6'));select pg_sleep(9); --" }

      it 'does not blow up' do
        expect(helper.timeout_refresh_path).to eq('/foo/bar?timeout=true')
      end
    end

    context 'with an invalid URI' do
      let(:path_info) { '/foo/bar/new.bac"938260%40' }

      it 'does not blow up' do
        expect(helper.timeout_refresh_path).to be_nil
      end
    end
  end
end
