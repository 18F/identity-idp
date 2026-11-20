require 'rails_helper'

RSpec.describe 'idv/session_errors/exception.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:try_again_path) { '/example/path' }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    decorated_sp_session = instance_double(
      ServiceProviderSession,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    assign(:try_again_path, try_again_path)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: contact_redirect_url,
    )
  end

  context 'with associated service provider' do
    let(:sp_name) { 'Example SP' }
    let(:sp_issuer) { 'example-issuer' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: contact_redirect_url,
      )
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the warning status page with the heading and copy' do
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('idv.failure.sessions.exception'),
      )
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        ".auth__form-page-body .copy--muted p a[href='#{contact_redirect_url}']",
        text: t('idv.failure.exceptions.link'),
      )
    end

    it 'renders a primary try again link' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button:not(.usa-button--secondary):not(.usa-button--tertiary)" \
        "[href='#{try_again_path}']",
        text: t('idv.failure.button.warning'),
      )
    end

    it 'renders contact support as a tertiary new-tab option with no heading' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[target=_blank][href='#{contact_redirect_url}']",
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
      expect(rendered).to_not have_css('.nds-troubleshooting-options h2')
    end
  end
end
