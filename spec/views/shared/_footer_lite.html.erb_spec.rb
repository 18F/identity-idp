require 'rails_helper'

RSpec.describe 'shared/_footer_lite.html.erb' do
  it 'contains link to help page' do
    render

    expect(rendered).to have_link(t('links.help'), href: help_center_redirect_url)
    expect(rendered).to have_selector("a[href='#{help_center_redirect_url}'][target='_blank']")
  end

  it 'contains link to contact page' do
    render

    expect(rendered).to have_link(t('links.contact'), href: contact_redirect_url)
    expect(rendered).to have_selector("a[href='#{contact_redirect_url}'][target='_blank']")
  end

  it 'contains link to privacy page' do
    render

    expect(rendered).to have_link(
      t('links.privacy_policy'),
      href: MarketingSite.security_and_privacy_practices_url,
    )
    expect(rendered).to have_selector(
      "a[href='#{MarketingSite.security_and_privacy_practices_url}'][target='_blank']",
    )
  end

  it 'contains GSA text' do
    render

    expect(rendered).to have_content(t('shared.footer_lite.gsa'))
  end
end
