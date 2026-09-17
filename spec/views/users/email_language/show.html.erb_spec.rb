require 'rails_helper'

RSpec.describe 'users/email_language/show.html.erb' do
  let(:user) { build_stubbed(:user, email_language: 'es') }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.edit_info.email_language'))

    render
  end

  context 'in the default layout' do
    it 'renders the legacy heading, radio list and submit' do
      render

      expect(rendered).to have_css('h1', text: t('account.email_language.edit_title'))
      expect(rendered).to have_css("form[action='#{account_email_language_path}']")
      expect(rendered).to have_checked_field('user[email_language]', with: 'es', visible: :all)
      expect(rendered).to have_button(t('forms.buttons.submit.default'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and languages copy' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('account.email_language.edit_title'),
      )
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('account.email_language.languages_list', app_name: APP_NAME),
      )
    end

    it 'renders a flat radio group with one option per locale, preselecting the user language' do
      render

      expect(rendered).to have_css('.radio-group .radio', count: I18n.available_locales.size)
      I18n.available_locales.each do |locale|
        expect(rendered).to have_css(
          ".radio input.radio__input[name='user[email_language]']" \
          "[value='#{locale}'][lang='#{locale}']",
          visible: :all,
        )
      end
      expect(rendered).to have_checked_field('user[email_language]', with: 'es', visible: :all)
      expect(rendered).to have_css(
        '.radio__label',
        text: t('account.email_language.default', language: t('i18n.locale.en')),
      )
    end

    it 'submits with a primary button and offers a secondary cancel to the account page' do
      render

      expect(rendered).to have_css(
        "form[action='#{account_email_language_path}'] input[name=_method][value=patch]",
        visible: :all,
      )
      expect(rendered).to have_css(
        '.auth__actions .actions button.usa-button[type=submit]',
        text: t('forms.buttons.submit.default'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button--secondary[href='#{account_path}']",
        text: t('links.cancel'),
      )
    end
  end
end
