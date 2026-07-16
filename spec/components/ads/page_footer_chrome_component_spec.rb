require 'rails_helper'

RSpec.describe ADS::PageFooterChromeComponent, type: :component do
  around do |example|
    with_request_url('/account?from=footer') { example.run }
  end

  it 'provides accessible native language navigation' do
    rendered = render_inline described_class.new
    select = rendered.at_css('select[name="locale"]')

    expect(rendered.at_css("label[for='#{select['id']}']").text).to eq(t('i18n.language'))
    expect(select.css('option').map { |option| option['lang'] })
      .to eq(I18n.available_locales.map(&:to_s))
    expect(select.at_css('option[selected]')['value']).to eq('/en/account?from=footer')
  end

  it 'exposes every secondary footer destination through the More select' do
    rendered = render_inline described_class.new
    select = rendered.at_css('select[name="footer_destination"]')
    destinations = select.css('option:not([disabled])').to_h do |option|
      [option.text, option['value']]
    end

    expect(rendered.at_css("label[for='#{select['id']}']").text)
      .to eq(t('links.more', default: 'More'))
    expect(destinations.keys).to contain_exactly(
      t('links.contact'),
      t('links.privacy_policy'),
      t('notices.privacy.privacy_act_statement'),
      t('links.accessibility_statement'),
    )
    expect(destinations.values).to all(be_present)
    expect(destinations[t('links.privacy_policy')])
      .to eq(MarketingSite.security_and_privacy_practices_url)
    expect(destinations[t('notices.privacy.privacy_act_statement')])
      .to eq(MarketingSite.privacy_act_statement_url)
    expect(destinations[t('links.accessibility_statement')])
      .to eq(MarketingSite.accessibility_statement_url)
  end

  it 'keeps the visible agency and help destinations as links' do
    rendered = render_inline described_class.new

    expect(rendered).to have_link(
      ADS::PageFooterChromeComponent::AGENCY_NAME,
      href: ADS::PageFooterChromeComponent::GSA_URL,
    )
    expect(rendered).to have_css(
      'a.ads-page-footer__help.ads-button.ads-button--quaternary.ads-button--sm[href]',
      text: t('links.help'),
    )
  end
end
