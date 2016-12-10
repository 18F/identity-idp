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

  describe '#timeout_refresh_url' do
    before { expect(helper).to receive(:request).and_return(double(original_url: original_url)) }

    context 'with no query in the request url' do
      let(:original_url) { 'http://test.host/foo/bar' }

      it 'adds timeout=true params' do
        expect(helper.timeout_refresh_url).to eq('http://test.host/foo/bar?timeout=true')
      end
    end

    context 'with params request url' do
      let(:original_url) { 'http://test.host/foo/bar?key=value' }

      it 'adds timeout=true param' do
        expect(helper.timeout_refresh_url).to eq('http://test.host/foo/bar?key=value&timeout=true')
      end
    end

    context 'with timeout=true in the query params already' do
      let(:original_url) { 'http://test.host/foo/bar?timeout=true' }

      it 'is the same' do
        expect(helper.timeout_refresh_url).to eq('http://test.host/foo/bar?timeout=true')
      end
    end
  end
end
