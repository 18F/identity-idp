require 'rails_helper'

describe 'idv/address/new' do
  let(:parsed_page) { Nokogiri::HTML.parse(rendered) }
  let(:guidance) { parsed_page.at_css('div#puerto-rico-extra-text') }
  let(:expected_text) { t('doc_auth.info.address_guidance_puerto_rico_html').gsub('<br>', '') }

  before do
    assign(
      :presenter,
      OpenStruct.new(
        address_line_1_hint: 'complete junk',
        pii: {},
      ),
    )
    render
  end

  it 'has the Puerto Rico guidance text' do
    expect(guidance.text).to match(/#{expected_text}/)
  end

  it 'initially hides the Puerto Rico guidance text' do
    expect(guidance.classes).to include('display-none')
  end
end
