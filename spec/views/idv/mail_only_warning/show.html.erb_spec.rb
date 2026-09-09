require 'rails_helper'

RSpec.describe 'idv/mail_only_warning/show.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:step_indicator_steps).and_return([])
    allow(view).to receive(:current_sp).and_return(nil)

    allow(view).to receive(:exit_url).and_return('/exit_url')
  end

  it 'lists options with correct interpolation' do
    expect(rendered).to include(APP_NAME)
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the outage heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('vendor_outage.alerts.pinpoint.idv.header'),
      )
    end

    it 'sets the verification header progress' do
      render

      progress = view.content_for(:nds_header_progress)
      expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
    end

    it 'renders the warning status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_selector('.nds-status-icon--warning .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the message, status link, and options list' do
      expect(rendered).to have_selector('.auth__form-page-body strong', text: APP_NAME)
      expect(rendered).to have_selector(
        '.auth__form-page-body a[target=_blank]',
        text: t('vendor_outage.alerts.pinpoint.idv.status_page_link'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body ul.usa-list.text-left li',
        count: t('vendor_outage.alerts.pinpoint.idv.options_html', app_name: APP_NAME).length,
      )
    end

    it 'renders the continue and exit actions' do
      expect(rendered).to have_link(t('doc_auth.buttons.continue'), href: idv_url)
      expect(rendered).to have_link(
        t('links.exit_login', app_name: APP_NAME),
        href: '/exit_url',
      )
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
