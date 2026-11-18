require 'rails_helper'

RSpec.describe 'two_factor_authentication/piv_cac_verification/error.html.erb' do
  let(:error) { 'user.not_found' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @presenter = PivCacErrorPresenter.new(
      error:,
      view:,
      try_again_url: login_two_factor_piv_cac_url,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('headings.piv_cac_login.account_not_found'))

    render
  end

  context 'in the default layout' do
    before do
      render
    end

    it 'renders the error status page with the presenter heading' do
      expect(rendered).to have_css('h1', text: t('headings.piv_cac_login.account_not_found'))
      expect(rendered).to have_content(t('instructions.mfa.piv_cac.having_trouble'))
      expect(rendered).to have_content(t('instructions.mfa.piv_cac.bullet_1'))
    end

    it 'links to signing in again, other methods and support' do
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.signing_in.text'),
        href: sign_out_url,
      )
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.another_method_text'),
        href: login_two_factor_options_url,
      )
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.bullet_3', app_name: APP_NAME),
        href: MarketingSite.contact_url,
      )
    end

    it 'renders the create-account sign-out button' do
      expect(rendered).to have_css(
        "form[action='#{login_two_factor_piv_cac_logout_url}'] input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_button(t('links.create_account'))
    end

    it 'renders the try again button' do
      expect(rendered).to have_link(t('links.try_again'), href: login_two_factor_piv_cac_url)
    end

    it 'renders the troubleshooting options and cancel link' do
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
      expect(rendered).to have_link(t('instructions.mfa.piv_cac.issues_with_piv_cac'))
      expect(rendered).to have_link(t('two_factor_authentication.add_or_change_authenticator'))
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_url)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the error icon and presenter heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('headings.piv_cac_login.account_not_found'),
      )
      expect(rendered).to have_css('h1', count: 1)
    end

    it 'renders the troubleshooting list from the design' do
      render

      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted p',
        text: t('instructions.mfa.piv_cac.having_trouble'),
      )
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted ul.list li',
        text: t('instructions.mfa.piv_cac.bullet_1'),
      )
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted ul.list li',
        text: t('nds.piv_cac_verification.error.bullet_2'),
      )
      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted ul.list li',
        text: t('nds.piv_cac_verification.error.bullet_3'),
      )
    end

    it 'links to Login.gov support' do
      render

      expect(rendered).to have_link(
        t('nds.piv_cac_verification.error.contact_support_link', app_name: APP_NAME),
        href: MarketingSite.contact_url,
      )
    end

    it 'keeps the create-account sign-out button as a tertiary action' do
      render

      expect(rendered).to have_css(
        '.auth__actions p.copy--muted',
        text: strip_tags(t('instructions.mfa.piv_cac.create_account_html', app_name: APP_NAME)),
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{login_two_factor_piv_cac_logout_url}'] " \
        "input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_css(
        '.auth__actions button.usa-button.usa-button--tertiary',
        text: t('links.create_account'),
      )
    end

    it 'renders a full-width try again primary button' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button[href='#{login_two_factor_piv_cac_url}']",
        text: t('links.try_again'),
      )
    end

    it 'renders the PIV/CAC troubleshooting options' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        ".nds-troubleshooting-options a[href='#{login_two_factor_options_path}']",
        text: t('two_factor_authentication.login_options_link_text'),
      )
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a[target=_blank]',
        text: t('instructions.mfa.piv_cac.issues_with_piv_cac'),
      )
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a[target=_blank]',
        text: t('two_factor_authentication.add_or_change_authenticator'),
      )
    end

    it 'provides a cancel button that signs the user out' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_out_url}']",
        text: t('links.cancel'),
      )
    end

    context 'with a certificate error' do
      let(:error) { 'certificate.expired' }

      it 'renders the matching presenter heading' do
        render

        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac.certificate.expired'),
        )
      end
    end

    context 'with an unknown error' do
      let(:error) { nil }

      it 'renders the generic did-not-work heading' do
        render

        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac.did_not_work'),
        )
      end
    end
  end
end
