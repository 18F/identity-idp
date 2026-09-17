require 'rails_helper'

RSpec.describe 'idv/proofing_agent_expired/show.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('idv.proofing_agent_expired.heading'))
    render
  end

  it 'renders the heading and continue button' do
    expect(rendered).to have_selector('h1', text: t('idv.proofing_agent_expired.heading'))
    expect(rendered).to have_button(t('idv.proofing_agent_expired.continue'))
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('idv.proofing_agent_expired.heading'),
      )
    end

    it 'renders the warning status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_selector('.nds-status-icon--warning .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the body copy' do
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('idv.proofing_agent_expired.body'),
      )
    end

    it 'renders the continue form posting to the expired path with a cancel link' do
      expect(rendered).to have_css("form[action='#{idv_proofing_agent_expired_path}']")
      expect(rendered).to have_selector(
        '.auth__actions button[type=submit]',
        text: t('idv.proofing_agent_expired.continue'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
