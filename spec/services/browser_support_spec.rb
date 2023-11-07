require 'rails_helper'

RSpec.describe BrowserSupport do
  before { BrowserSupport.clear_cache! }

  describe '.supported?' do
    let(:user_agent) do
      # Chrome v110
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like ' \
        'Gecko) Chrome/110.0.0.0 Safari/537.36'
    end

    subject(:supported) { BrowserSupport.supported?(user_agent) }

    context 'with browser support config file missing' do
      before do
        expect(File).to receive(:read).once.with(Rails.root.join('browsers.json')).
          and_raise(Errno::ENOENT.new)
      end

      it { expect(supported).to eq(true) }

      it 'memoizes result of parsing browser config' do
        BrowserSupport.supported?('a')
        BrowserSupport.supported?('b')
      end
    end

    context 'with invalid support config' do
      before do
        expect(File).to receive(:read).once.with(Rails.root.join('browsers.json')).
          and_return('invalid')
      end

      it { expect(supported).to eq(true) }

      it 'memoizes result of parsing browser config' do
        BrowserSupport.supported?('a')
        BrowserSupport.supported?('b')
      end
    end

    context 'with valid browser support config' do
      before do
        allow(BrowserSupport).to receive(:browser_support_config).and_return(
          ['chrome 109', 'and_chr 108', 'ios_saf 14.5-14.8', 'op_mini all', 'android 119'],
        )
      end

      context 'with nil user agent' do
        let(:user_agent) { nil }

        it { expect(supported).to eq(false) }
      end

      context 'with supported user agent' do
        let(:user_agent) do
          # Chrome v110
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like ' \
            'Gecko) Chrome/110.0.0.0 Safari/537.36'
        end

        it { expect(supported).to eq(true) }
      end

      context 'with unsupported user agent' do
        let(:user_agent) do
          # Chrome v108
          'Mozilla/5.0 (X11; CrOS x86_64 8172.45.0) AppleWebKit/537.36 (KHTML, like Gecko) ' \
            'Chrome/108.0.2704.64 Safari/537.36'
        end

        it { expect(supported).to eq(false) }
      end

      context 'with user agent for non-numeric version test' do
        let(:user_agent) do
          # Opera v12
          'Opera/9.80 (Android; Opera Mini/36.2.2254/119.132; U; id) Presto/2.12.423 Version/12.16)'
        end

        it { expect(supported).to eq(true) }
      end

      context 'with user agent for version range test' do
        context 'below version range' do
          let(:user_agent) do
            # Safari v11.2
            'Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, ' \
              'like Gecko) Version/11.2 Mobile/15E148 Safari/604.1'
          end

          it { expect(supported).to eq(false) }
        end

        context 'within version range' do
          let(:user_agent) do
            # Safari v14.6
            'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, ' \
              'like Gecko) Mobile/15E148 Version/14.6 Safari/605.1.15 AlohaBrowser/3.1.5'
          end

          it { expect(supported).to eq(true) }
        end

        context 'above version range' do
          let(:user_agent) do
            # Safari v16.3
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML' \
              ', like Gecko) Version/16.3 Mobile/15E148 Safari/604.1'
          end

          it { expect(supported).to eq(true) }
        end
      end

      context 'with user agent for platform-specific version support' do
        let(:user_agent) do
          # Android Chrome v108
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) ' \
            'Chrome/108.0.5481.153 Mobile Safari/537.36'
        end

        it { expect(supported).to eq(true) }
      end

      context 'with user agent for webview parsed as chrome' do
        context 'with version below supported range' do
          let(:user_agent) do
            # Android WebView v109
            'Mozilla/5.0 (Linux; Android 7.0; mione A55 Build/NRD90M; wv) AppleWebKit/537.36 ' \
              '(KHTML, like Gecko) Version/4.0 Chrome/109.0.5414.85 Mobile Safari/537.36'
          end

          it { expect(supported).to eq(false) }
        end

        context 'with version within supported range' do
          let(:user_agent) do
            # Android WebView v119
            'Mozilla/5.0 (Linux; Android 13; SM-A546B Build/TP1A.220624.014; wv) ' \
              'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/119.0.6045.66 Mobile ' \
              'Safari/537.36'
          end

          it { expect(supported).to eq(true) }
        end
      end
    end
  end
end
