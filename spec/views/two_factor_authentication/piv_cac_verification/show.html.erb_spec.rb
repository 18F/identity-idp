require 'rails_helper'

RSpec.describe 'two_factor_authentication/piv_cac_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }
  let(:reauthn) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_signing_up?).and_return(false)
    @presenter = TwoFactorAuthCode::PivCacAuthenticationPresenter.new(
      data: { two_factor_authentication_method: 'piv_cac', reauthn: },
      view: ActionController::Base.new.view_context,
      service_provider: nil,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.present_piv_cac'))

    render
  end

  context 'in the default layout' do
    before do
      render
    end

    it 'shows the PIV/CAC heading and instructions' do
      expect(rendered).to have_css('h1', text: t('two_factor_authentication.piv_cac_header_text'))
      expect(rendered).to have_content(t('instructions.mfa.piv_cac.confirm_piv_cac'))
    end

    it 'renders the spinner button linking to the PIV/CAC service redirect' do
      expect(rendered).to have_css('lg-spinner-button')
      expect(rendered).to have_link(
        t('forms.piv_cac_mfa.submit'),
        href: /#{Regexp.escape(login_two_factor_piv_cac_present_piv_cac_path)}\z/,
      )
    end

    it 'renders the PIV/CAC troubleshooting options' do
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
      expect(rendered).to have_link(t('instructions.mfa.piv_cac.issues_with_piv_cac'))
      expect(rendered).to have_link(t('two_factor_authentication.add_or_change_authenticator'))
    end

    it 'provides a cancel link that signs the user out' do
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'user is reauthenticating' do
      let(:reauthn) { true }

      it 'provides a cancel link to return to the account page' do
        expect(rendered).to have_link(t('links.cancel'), href: account_path)
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the PIV/CAC heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.piv_cac_header_text'),
      )
    end

    it 'renders the Figma sign-in instructions instead of the legacy copy' do
      render

      expect(rendered).to have_css(
        '.auth__form-page-body .copy--muted',
        text: t('instructions.mfa.piv_cac.sign_in', app_name: APP_NAME),
      )
      expect(rendered).to_not have_content(t('instructions.mfa.piv_cac.confirm_piv_cac'))
    end

    it 'renders a full-width Continue spinner button to the PIV/CAC service redirect' do
      render

      expect(rendered).to have_css(
        ".auth__actions lg-spinner-button a.usa-button[href$='" \
        "#{login_two_factor_piv_cac_present_piv_cac_path}']",
        text: t('forms.buttons.continue'),
      )
    end

    it 'renders the choose-another-method tertiary button' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button[href='#{login_two_factor_options_path}']",
        text: t('nds.mfa.choose_another_method'),
      )
    end

    it 'renders the remaining PIV/CAC troubleshooting options in new tabs' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        'a[target=_blank]',
        text: t('instructions.mfa.piv_cac.issues_with_piv_cac'),
      )
      expect(rendered).to have_css(
        'a[target=_blank]',
        text: t('two_factor_authentication.add_or_change_authenticator'),
      )
      expect(rendered).to_not have_link(t('two_factor_authentication.login_options_link_text'))
    end

    it 'provides a cancel button that signs the user out' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_out_path}']",
        text: t('links.cancel'),
      )
    end

    context 'user is reauthenticating' do
      let(:reauthn) { true }

      it 'cancels back to the account page' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'user is signing up' do
      before do
        allow(view).to receive(:user_signing_up?).and_return(true)
      end

      it 'cancels to the sign-up cancel path' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel'),
        )
      end
    end
  end
end
