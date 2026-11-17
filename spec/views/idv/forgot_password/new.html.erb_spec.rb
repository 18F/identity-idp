require 'rails_helper'

RSpec.describe 'idv/forgot_password/new.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.idv.reset_password'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the heading and warnings' do
      expect(rendered).to have_selector('h1', text: t('idv.forgot_password.modal_header'))
      t('idv.forgot_password.warnings').each do |warning|
        expect(rendered).to have_selector('li', text: warning)
      end
    end

    it 'renders try again and reset password actions' do
      expect(rendered).to have_link(
        t('idv.forgot_password.try_again'),
        href: idv_enter_password_path,
      )
      expect(rendered).to have_selector(
        "form[action='#{idv_forgot_password_path}'][method='post']",
      )
      expect(rendered).to have_button(t('idv.forgot_password.reset_password'))
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

    it 'has a title matching the forgot password heading' do
      expect(view.content_for(:title)).to eq(t('idv.forgot_password.modal_header'))
    end

    it 'renders the form-page card with the info badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth__header .nds-status-icon.nds-status-icon--info svg[aria-hidden="true"]',
      )
      expect(rendered).to include(NDS::IconComponent.markup_for('nds/icons/info/24.svg'))
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('h1', text: t('idv.forgot_password.modal_header'))
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the warnings as a list' do
      t('idv.forgot_password.warnings').each do |warning|
        expect(rendered).to have_selector('.auth__form-page-body li', text: warning)
      end
    end

    it 'renders try again as the primary action' do
      expect(rendered).to have_selector(
        ".auth__actions a.usa-button[href='#{idv_enter_password_path}']",
        text: t('idv.forgot_password.try_again'),
      )
    end

    it 'renders reset password as a tertiary POST to the forgot password path' do
      expect(rendered).to have_selector(
        ".auth__actions form[action='#{idv_forgot_password_path}'][method='post']",
      )
      expect(rendered).to have_button(
        t('idv.forgot_password.reset_password'),
        class: 'usa-button--tertiary',
      )
    end
  end
end
