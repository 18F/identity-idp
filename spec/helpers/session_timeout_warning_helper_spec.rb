require 'rails_helper'

describe SessionTimeoutWarningHelper do
  describe '#time_left_in_session' do
    it 'describes time left based on when the timeout warning appears' do
      allow(Figaro.env).
        to receive(:session_check_frequency).and_return('1')
      allow(Figaro.env).
        to receive(:session_check_delay).and_return('2')
      allow(Figaro.env).
        to receive(:session_timeout_warning_seconds).and_return('3')

      expect(helper.time_left_in_session).
        to eq distance_of_time_in_words(time_between_warning_and_timeout)
    end
  end

  def time_between_warning_and_timeout
    Figaro.env.session_timeout_warning_seconds.to_i
  end

  describe '#timeout_refresh_path' do
    let(:http_host) { 'example.com' }
    before do
      allow(helper).to receive(:request).and_return(
        ActionDispatch::Request.new(
          'HTTP_HOST' => http_host,
          'PATH_INFO' => path_info,
          'rack.url_scheme' => 'https'
        )
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
  end
end
