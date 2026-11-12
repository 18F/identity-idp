require 'rails_helper'

RSpec.describe 'users/webauthn_platform_recommended/new.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('webauthn_platform_recommended.heading'))

    render
  end

  context 'in the default layout' do
    it 'renders separate forms with submission for options to add' do
      expect(rendered).to have_css('form:has(input[name=add_method]):has([type=submit])')
      expect(rendered).to have_css('form:not(:has(input[name=add_method])):has([type=submit])')
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has the NDS localized title' do
      expect(view).to receive(:title=).with(t('nds.webauthn_platform_recommended.heading'))

      render
    end

    it 'renders the form-page card with the info icon, heading and body' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon svg.usa-icon')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('nds.webauthn_platform_recommended.heading'),
      )
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('nds.webauthn_platform_recommended.description'),
      )
      info_before, info_after = t(
        'nds.webauthn_platform_recommended.info_html',
        phishing_resistant_html: '|',
      ).split('|')
      expect(rendered).to have_selector('.auth__form-page-body .copy p', text: info_before.strip)
      expect(rendered).to have_selector('.auth__form-page-body .copy p', text: info_after.strip)
    end

    it 'links phishing-resistant to the authentication methods help article in a new tab' do
      expect(rendered).to have_link(
        t('nds.webauthn_platform_recommended.phishing_resistant'),
        href: help_center_redirect_path(
          category: 'get-started',
          article: 'authentication-methods',
          flow: :two_factor_authentication,
          step: :webauthn_platform_recommended,
        ),
      )
      expect(rendered).to have_css(
        '.auth__form-page-body .copy p a[target=_blank]',
        text: t('nds.webauthn_platform_recommended.phishing_resistant'),
      )
    end

    it 'renders a primary add-passkey submit above a tertiary skip submit' do
      expect(rendered).to have_css(
        ".auth__actions .actions form[action='#{webauthn_platform_recommended_url}'][method=post]",
        count: 2,
      )
      expect(rendered).to have_css(
        '.actions lg-submit-button:nth-of-type(1) form input[name=add_method][value=true]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.actions lg-submit-button:nth-of-type(1) button.usa-button:not(.usa-button--tertiary)',
        text: t('nds.webauthn_platform_recommended.cta'),
      )
      expect(rendered).to have_css(
        '.actions lg-submit-button:nth-of-type(2) button.usa-button--tertiary',
        text: t('webauthn_platform_recommended.skip'),
      )
      expect(rendered).to_not have_css(
        '.actions lg-submit-button:nth-of-type(2) input[name=add_method]',
        visible: :all,
      )
    end
  end
end
