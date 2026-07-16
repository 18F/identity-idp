require 'rails_helper'

RSpec.describe ADS::OfficialBannerComponent, type: :component do
  it 'renders the official site text' do
    rendered = render_inline(described_class.new)

    expect(rendered.text).to include(t('shared.banner.official_site'))
  end

  context 'when the no-PII banner is enabled' do
    before { allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(true) }

    it 'renders the sandbox test notice' do
      rendered = render_inline(described_class.new)

      expect(rendered.text).to include(t('idv.messages.sessions.no_pii'))
      expect(rendered.css('.ads-official-banner__test-notice')).to be_present
    end
  end

  context 'when the no-PII banner is disabled' do
    before { allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(false) }

    it 'does not render the sandbox test notice' do
      rendered = render_inline(described_class.new)

      expect(rendered.text).not_to include(t('idv.messages.sessions.no_pii'))
      expect(rendered.css('.ads-official-banner__test-notice')).to be_empty
    end
  end
end
