require 'rails_helper'

RSpec.describe 'idv/phone_required/show.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(true)
    render
  end

  it 'renders the error card with the phone-required copy and no actions' do
    expect(rendered).to have_css('.nds-status-icon--error')
    expect(rendered).to have_css('.auth--form-page h1', text: t('nds.phone_required.heading'))
    expect(rendered).to have_css('.auth__form-page-body hr.divider')
    expect(rendered).to have_text(t('nds.phone_required.info'))
    expect(rendered).not_to have_css('.auth__actions')
  end
end
