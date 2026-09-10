require 'rails_helper'

RSpec.describe 'users/duplicate_profiles_please_call/show.html.erb' do
  let(:nds_layout) { false }
  let(:contact_number) { IdentityConfig.store.idv_contact_phone_number }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    render
  end

  it 'renders the heading and error details' do
    expect(rendered).to have_css('h1', text: t('users.duplicate_profiles_please_call.heading'))
    expect(rendered).to have_css('strong', text: 'LG33')
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'links the contact number as a non-wrapping tel: link' do
      expect(rendered).to have_css(
        "a.text-no-wrap[href='tel:#{contact_number.gsub(/\D/, '')}']",
        text: contact_number,
      )
    end

    it 'renders the error code as an inline field readout' do
      expect(rendered).to have_css('p .field-readout--inline .field-readout__value', text: 'LG33')
    end

    it 'keeps the help link' do
      expect(rendered).to have_link(href: MarketingSite.help_url)
    end
  end
end
