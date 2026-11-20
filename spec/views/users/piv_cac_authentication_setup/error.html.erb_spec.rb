require 'rails_helper'

RSpec.describe 'users/piv_cac_authentication_setup/error.html.erb' do
  let(:error) { 'certificate.none' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @presenter = PivCacErrorPresenter.new(
      error:,
      view:,
      try_again_url: setup_piv_cac_url,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('headings.piv_cac.certificate.none'))

    render
  end

  context 'in the default layout' do
    before do
      render
    end

    it 'renders the error status page with the presenter heading and description' do
      expect(rendered).to have_css('h1', text: t('headings.piv_cac.certificate.none'))
      expect(rendered).to have_link(
        t('instructions.mfa.piv_cac.try_again'),
        href: setup_piv_cac_url,
      )
    end

    it 'renders the try again button' do
      expect(rendered).to have_link(t('forms.piv_cac_setup.try_again'), href: setup_piv_cac_url)
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

    it 'renders the form-page card with the error icon and presenter heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header--with-media .nds-status-icon--error .usa-icon')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('headings.piv_cac.certificate.none'),
      )
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
    end

    it 'renders the presenter description with its inline try again link' do
      expect(rendered).to have_css('.auth__form-page-body .copy--muted > p', count: 1)
      expect(rendered).to have_css(
        ".auth__form-page-body .copy--muted p a[href='#{setup_piv_cac_url}']",
        text: t('instructions.mfa.piv_cac.try_again'),
      )
    end

    it 'renders a single primary try again button' do
      expect(rendered).to have_css('.auth__actions .usa-button', count: 1)
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button[href='#{setup_piv_cac_url}']",
        text: t('forms.piv_cac_setup.try_again'),
      )
      expect(rendered).not_to have_css(
        '.auth__actions .usa-button--secondary, .auth__actions .usa-button--tertiary',
      )
    end

    context 'when the PIV/CAC is already associated with another account' do
      let(:error) { 'piv_cac.already_associated' }

      it 'renders the matching heading and description' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('headings.piv_cac_setup.already_associated'),
        )
        expect(rendered).to have_css(
          ".auth__form-page-body .copy--muted p a[href='#{setup_piv_cac_url}']",
          text: t('instructions.mfa.piv_cac.try_again'),
        )
      end
    end

    context 'with a plain-text description' do
      let(:error) { 'token.http_failure' }

      it 'wraps the description in a paragraph' do
        expect(rendered).to have_css(
          '.auth__form-page-body .copy--muted > p',
          text: t('instructions.mfa.piv_cac.http_failure'),
        )
      end
    end
  end
end
