require 'rails_helper'

describe 'pages/privacy_policy.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.privacy_policy'))

    render
  end

  it 'links to the system of record notices' do
    sorn_url = <<-EOS.gsub(/\s/, '')
      https://www.federalregister.gov/documents/2017/01/19/2017-01174
      /privacy-act-of-1974-notice-of-a-new-system-of-records
    EOS

    render

    expect(rendered).
      to have_link(t('pages.privacy_policy.systems_of_record_notices'), href: sorn_url)
  end

  it 'links to the contact form' do
    render

    expect(rendered).
      to have_link(t('pages.privacy_policy.contact_form_link'), href: contact_path)
  end
end
