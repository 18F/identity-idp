require 'rails_helper'

RSpec.describe BrowserCache do
  let(:chrome_user_agent) do
    'Mozilla/5.0 (X11; CrOS x86_64 8172.45.0) AppleWebKit/537.36 (KHTML, like Gecko) \
      Chrome/51.0.2704.64 Safari/537.36'
  end

  before { BrowserCache.clear }

  describe '.parse' do
    it 'parses a user agent using Browser gem' do
      browser = BrowserCache.parse(chrome_user_agent)
      expect(browser.name).to eq('Chrome')
      expect(browser.platform.name).to eq('Chrome OS')
      expect(browser.mobile?).to eq(false)
    end

    it 'caches by user agent' do
      expect(Browser).to receive(:new).once.and_call_original

      3.times { BrowserCache.parse(chrome_user_agent) }
    end
  end
end
