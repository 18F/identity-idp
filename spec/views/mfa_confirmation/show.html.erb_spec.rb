require 'rails_helper'

RSpec.describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:enforce_second_mfa?).and_return(true)
    @content = MfaConfirmationPresenter.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.mfa_setup.suggest_second_mfa'))

    render
  end

  context 'in the default layout' do
    it 'has a heading' do
      render

      expect(rendered).to have_content(@content.heading)
    end

    it 'provides a context for adding another MFA method' do
      render

      expect(rendered).to have_selector(
        'p',
        class: 'margin-top-1 margin-bottom-4',
      )
    end

    it 'provides a call to action to add another MFA method' do
      render

      expect(rendered).to have_selector(
        'a',
        text: @content.button,
      )
    end

    it 'has link to skip add mfa' do
      render

      expect(rendered).to have_button(
        t('mfa.skip'),
      )
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'when the user only has enabled mfa webauthn platform' do
      let(:user) { create(:user, :with_webauthn_platform) }

      before do
        @content = MfaConfirmationPresenter.new(
          show_skip_additional_mfa_link: false,
          webauthn_platform_set_up_successful: true,
        )
      end

      it 'does not show link to skip add mfa' do
        render

        expect(rendered).not_to have_button(
          t('mfa.skip'),
        )
      end

      it 'shows the correct localized title after setup' do
        render

        expect(rendered).to have_content(
          t('titles.mfa_setup.face_touch_unlock_confirmation'),
        )
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the backup method heading and copy' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('nds.mfa_confirmation.heading'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('mfa.account_info'),
      )
    end

    it 'renders the add-method primary button above a tertiary skip submit' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button[href='#{authentication_methods_setup_path}']",
        text: t('nds.mfa_confirmation.add_method'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions form[action='#{auth_method_confirmation_skip_path}'][method=post]",
      )
      expect(rendered).to have_css(
        '.auth__actions .actions form button.usa-button.usa-button--tertiary',
        text: t('nds.mfa_confirmation.skip'),
      )
      expect(rendered).to have_css('.actions > a + form')
    end

    it 'does not render the legacy illustration or heading' do
      render

      expect(rendered).to_not have_css('img[src*="user-signup"]')
      expect(rendered).to_not have_content(t('titles.mfa_setup.suggest_second_mfa'))
      expect(rendered).to_not have_button(t('mfa.skip'))
    end

    context 'when the user only has enabled mfa webauthn platform' do
      let(:user) { create(:user, :with_webauthn_platform) }

      before do
        @content = MfaConfirmationPresenter.new(
          show_skip_additional_mfa_link: false,
          webauthn_platform_set_up_successful: true,
        )
      end

      it 'keeps the face or touch unlock heading and copy' do
        render

        expect(rendered).to have_selector(
          '.auth--form-page h1',
          text: t('titles.mfa_setup.face_touch_unlock_confirmation'),
        )
        expect(rendered).to have_selector(
          '.auth__form-page-body .copy p',
          text: t('mfa.webauthn_platform_message'),
        )
      end

      it 'keeps the add-method button and does not offer skip' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{authentication_methods_setup_path}']",
          text: t('nds.mfa_confirmation.add_method'),
        )
        expect(rendered).to_not have_css("form[action='#{auth_method_confirmation_skip_path}']")
        expect(rendered).to_not have_button(t('nds.mfa_confirmation.skip'))
      end
    end
  end
end
