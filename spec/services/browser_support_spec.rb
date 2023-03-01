require 'rails_helper'

RSpec.describe BrowserSupport do
  before { BrowserSupport.cache.clear }

  describe '.supported?' do
    let(:user_agent) do
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like ' \
        'Gecko) Chrome/110.0.0.0 Safari/537.36'
    end

    subject(:supported) { BrowserSupport.supported?(user_agent) }

    context 'with browser support config file missing' do
      before do
        expect(File).to receive(:read).with(Rails.root.join('browsers.json')).
          and_raise(Errno::ENOENT.new)
      end

      it { expect(supported).to eq(true) }
    end

    context 'with invalid support config' do
      before do
        expect(File).to receive(:read).with(Rails.root.join('browsers.json')).and_return('invalid')
      end

      it { expect(supported).to eq(true) }
    end

    context 'with valid browser support config' do
      before do
        allow(BrowserSupport).to receive(:browser_support_config).and_return(['chrome 109'])
      end

      context 'with nil user agent' do
        let(:user_agent) { nil }

        it { expect(supported).to eq(false) }
      end

      context 'with supported user agent' do
        let(:user_agent) do
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like ' \
            'Gecko) Chrome/110.0.0.0 Safari/537.36'
        end

        it { expect(supported).to eq(true) }
      end

      context 'with unsupported user agent' do
        let(:user_agent) do
          'Mozilla/5.0 (X11; CrOS x86_64 8172.45.0) AppleWebKit/537.36 (KHTML, like Gecko) \
            Chrome/51.0.2704.64 Safari/537.36'
        end

        it { expect(supported).to eq(false) }
      end
    end
  end
end
