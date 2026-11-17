require 'rails_helper'

RSpec.describe 'idv/activated.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('idv.titles.activated'))

    render
  end

  context 'in the default layout' do
    it 'has a localized heading' do
      render

      expect(rendered).to have_selector('h1', text: t('idv.titles.activated'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the check badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth__header .nds-status-icon svg[aria-hidden="true"]')
      expect(rendered).to include(NDS::IconComponent.markup_for('nds/icons/check_circle/24.svg'))
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('h1', text: t('idv.titles.activated'))
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the verified message with the contact link' do
      expect(rendered).to have_text(
        strip_tags(
          t('idv.messages.activated_html', link_html: t('idv.messages.activated_link')),
        ),
      )
      expect(rendered).to have_link(t('idv.messages.activated_link'), href: contact_redirect_url)
    end

    it 'renders no actions' do
      expect(rendered).not_to have_selector('.auth__actions')
    end
  end
end
