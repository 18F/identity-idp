require 'rails_helper'

RSpec.describe 'idv/phone_required/show.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(true)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('nds.phone_required.heading'))

    render
  end

  context 'when rendered' do
    before { render }

    it 'renders the error card with the phone-required copy and no actions' do
      expect(rendered).to have_css('.nds-status-icon--error')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.phone_required.heading'))
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_text(t('nds.phone_required.info'))
      expect(rendered).not_to have_css('.auth__actions')
    end

    it 'sets the verification header progress to the hybrid handoff substep' do
      expect(Capybara.string(view.content_for(:nds_header_progress))).to have_css(
        '.progress__step-counter',
        text: '3 / 12',
      )
    end
  end
end
