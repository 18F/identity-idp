require 'rails_helper'

RSpec.describe 'users/piv_cac_login/error.html.erb' do
  let(:error) { 'user.not_found' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @presenter = PivCacErrorPresenter.new(
      error:,
      view:,
      try_again_url: login_piv_cac_url,
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

    it 'renders the error status page with the presenter heading and description' do
      expect(rendered).to have_css('h1', text: t('headings.piv_cac_login.account_not_found'))
      expect(rendered).to have_link(t('headings.sign_in_without_sp'), href: root_url)
      expect(rendered).to have_link(t('links.create_account'), href: sign_up_email_url)
    end

    it 'renders the back to sign in button' do
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.back_to_sign_in'),
        href: new_user_session_url,
      )
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
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
    end

    it 'renders the presenter description with its sign in and create account links' do
      render

      expect(rendered).to have_css('.auth__form-page-body .copy--muted > p', count: 2)
      expect(rendered).not_to have_css('.auth__form-page-body .copy--muted p p')

      expect(rendered).to have_css(
        ".auth__form-page-body .copy--muted a[href='#{root_url}']",
        text: t('headings.sign_in_without_sp'),
      )
      expect(rendered).to have_css(
        ".auth__form-page-body .copy--muted a[href='#{sign_up_email_url}']",
        text: t('links.create_account'),
      )
    end

    it 'renders a full-width back to sign in button' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button.usa-button--secondary" \
        "[href='#{new_user_session_url}']",
        text: t('instructions.mfa.piv_cac.back_to_sign_in'),
      )
    end

    context 'with an expired certificate' do
      let(:error) { 'certificate.expired' }

      it 'renders the matching heading and a try again link' do
        render

        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac.certificate.expired'),
        )
        expect(rendered).to have_css(
          ".auth__form-page-body .copy--muted p a[href='#{login_piv_cac_url}']",
          text: t('instructions.mfa.piv_cac.please_try_again'),
        )
        expect(rendered).to have_css('.auth__form-page-body .copy--muted > p', count: 1)
      end
    end

    context 'with no certificate' do
      let(:error) { 'certificate.none' }

      it 'renders the matching heading and a try again link' do
        render

        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac.certificate.none'),
        )
        expect(rendered).to have_css(
          ".auth__form-page-body .copy--muted p a[href='#{login_piv_cac_url}']",
          text: t('instructions.mfa.piv_cac.try_again'),
        )
      end
    end

    context 'with a server timeout' do
      let(:error) { 'token.http_failure' }

      it 'renders the internal error heading and timeout description' do
        render

        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac.token.missing'),
        )
        expect(rendered).to have_css(
          '.auth__form-page-body .copy--muted p',
          text: t('instructions.mfa.piv_cac.http_failure'),
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
