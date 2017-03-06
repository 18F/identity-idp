require 'rails_helper'

describe 'pages/privacy_policy.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.privacy_policy'))

    render
  end

  let(:doc) { Nokogiri::HTML(rendered) }

  it 'links to the system of record notices in a new window' do
    sorn_url = <<-EOS.gsub(/\s/, '')
      https://www.federalregister.gov/documents/2017/01/19/2017-01174
      /privacy-act-of-1974-notice-of-a-new-system-of-records
    EOS

    render

    link = doc.css("a[href='#{sorn_url}']").first
    expect(link).to be_present
    expect(link.text).to eq(t('pages.privacy_policy.systems_of_record_notices'))
    expect(link[:target]).to eq('_blank')
  end

  it 'links to the e-Government act in a new window' do
    egov_url = 'https://www.gpo.gov/fdsys/pkg/PLAW-107publ347/html/PLAW-107publ347.htm'

    render

    link = doc.css("a[href='#{egov_url}']").first
    expect(link).to be_present
    expect(link.text).to eq(t('pages.privacy_policy.e_government_link'))
    expect(link[:target]).to eq('_blank')
  end

  it 'links to the contact form' do
    render

    expect(rendered).
      to have_link(t('pages.privacy_policy.contact_form_link'), href: contact_path)
  end
end
