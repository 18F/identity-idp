require 'rails_helper'

RSpec.describe 'sign_in_security_check_failed/show.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('security_check_failed.title'))
    render
  end

  it 'renders the heading' do
    expect(rendered).to have_selector('h1', text: t('security_check_failed.title'))
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
        text: t('security_check_failed.title'),
      )
    end

    it 'renders the warning status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_selector('.nds-status-icon--warning .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the details, learn-more link, and info list' do
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('security_check_failed.details'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body a[target=_blank]',
        text: t('security_check_failed.learn_more', app_name: APP_NAME),
      )
      expect(rendered).to have_selector('.auth__form-page-body ul.usa-list li', count: 3)
    end

    it 'renders the contact and back actions' do
      expect(rendered).to have_selector(
        '.auth__actions a[target=_blank][href="' + contact_redirect_url + '"]',
        text: t('security_check_failed.contact', app_name: APP_NAME),
      )
      expect(rendered).to have_link(t('forms.buttons.back'), href: root_url)
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
