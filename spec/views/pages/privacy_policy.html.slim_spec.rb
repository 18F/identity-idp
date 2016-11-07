require 'rails_helper'

describe 'pages/privacy_policy.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.privacy_policy'))

    render
  end

  it 'links to the system of record notices' do
    pending 'having the correct link'

    render

    doc = Nokogiri::HTML(rendered)
    link_title = t('pages.privacy_policy.systems_of_record_notices')
    expect(doc.xpath("//a[text()='#{link_title}']").first[:href]).to_not eq('#')
  end

  it 'links to the contact form' do
    render

    expect(rendered).
      to have_link(t('pages.privacy_policy.contact_form_link'), href: contact_path)
  end
end
