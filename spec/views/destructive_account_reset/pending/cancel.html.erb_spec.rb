require 'rails_helper'

RSpec.describe 'destructive_account_reset/pending/cancel.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.pending.canceled'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the legacy heading and sign in link' do
      expect(rendered).to have_css('h1', text: t('destructive_account_reset.pending.canceled'))
      expect(rendered).to have_link(
        t('links.continue_sign_in'),
        href: user_two_factor_authentication_path,
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).not_to have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the canceled heading and info' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('nds.destructive_account_reset.pending.canceled_heading'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('destructive_account_reset.pending.canceled_info', app_name: APP_NAME),
      )
    end

    it 'links back to the two factor authentication page to sign in' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{user_two_factor_authentication_path}']",
        text: t('links.continue_sign_in'),
      )
    end
  end
end
