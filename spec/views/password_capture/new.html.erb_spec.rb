require 'rails_helper'

RSpec.describe 'password_capture/new.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:password_header) { t('headings.passwords.confirm') }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:password_header).and_return(password_header)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.visitors.index'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the heading and the password form' do
      expect(rendered).to have_css('h1', text: password_header)
      expect(rendered).to have_css("form[action='#{capture_password_url}'][method='post']")
      expect(rendered).to have_field(t('account.index.password'), type: 'password')
      expect(rendered).to have_button(t('forms.buttons.submit.default'))
      expect(rendered).to have_link(t('links.passwords.forgot'), href: new_user_password_url)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the password heading' do
      expect(view).to receive(:title=).with(t('headings.passwords.confirm'))

      render
    end

    it 'renders the form-page card with the heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro h1', text: password_header)
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('idv.messages.sessions.enter_password_message', app_name: APP_NAME),
      )
    end

    it 'posts the same user[password] field to the capture password path' do
      render

      expect(rendered).to have_css(
        "form[action='#{capture_password_url}'][method='post'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css(
        "input.usa-input__control--password[name='user[password]']" \
          "[autocomplete='current-password'][required]",
      )
      expect(rendered).to have_field(t('account.index.password'), type: 'password')
    end

    it 'renders the continue and forgot password actions' do
      render

      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{new_user_password_url}']",
        text: t('links.passwords.forgot'),
      )
    end

    context 'when the user needs a new personal key' do
      let(:password_header) { t('headings.passwords.confirm_for_personal_key') }

      it 'has a title matching the personal key heading' do
        expect(view).to receive(:title=).with(t('headings.passwords.confirm_for_personal_key'))

        render
      end

      it 'renders the personal key heading' do
        render

        expect(rendered).to have_css('.auth__intro h1', text: password_header)
      end
    end

    context 'after an incorrect password' do
      before { flash[:error] = t('errors.confirm_password_incorrect') }

      it 'renders the error in the card' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error',
          text: t('errors.confirm_password_incorrect'),
        )
      end
    end
  end
end
