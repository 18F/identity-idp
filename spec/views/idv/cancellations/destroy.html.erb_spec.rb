require 'rails_helper'

RSpec.describe 'idv/cancellations/destroy.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.idv.canceled'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders heading' do
      expect(rendered).to have_text(t('idv.cancel.headings.confirmation.hybrid'))
    end

    it 'renders content' do
      expect(rendered).to have_text(t('doc_auth.instructions.switch_back'))
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'has a title matching the canceled heading' do
      expect(view.content_for(:title)).to eq(t('idv.cancel.headings.confirmation.hybrid'))
    end

    it 'renders the form-page card with the heading and switch back instructions' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('h1', text: t('idv.cancel.headings.confirmation.hybrid'))
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('doc_auth.instructions.switch_back'),
      )
    end

    it 'renders no actions' do
      expect(rendered).not_to have_selector('.auth__actions')
    end
  end
end
