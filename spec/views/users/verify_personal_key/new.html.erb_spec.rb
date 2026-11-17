require 'rails_helper'

RSpec.describe 'users/verify_personal_key/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('forms.personal_key.title'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the personal key form' do
      expect(rendered).to have_css('h1', text: t('forms.personal_key.title'))
      expect(rendered).to have_css(
        "form[action='#{create_verify_personal_key_path}'] input[name='personal_key']",
      )
    end

    it 'renders the reverify and cancel links' do
      expect(rendered).to have_css(
        "form[action='#{reactivate_account_path}'] button",
        text: t('links.reverify'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and new-key subtitle' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('forms.personal_key.title'))
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.verify_personal_key.info'),
      )
    end

    it 'posts the same personal_key field with the legacy formatting rules' do
      render

      form = Nokogiri::HTML(rendered).at_css(
        "form[action='#{create_verify_personal_key_path}'][method='post'][data-nds-submit-gate]",
      )
      expect(form).to be_present
      input = form.at_css('input[name="personal_key"]')
      expect(input[:required]).to be_present
      expect(input[:autocomplete]).to eq('off')
      expect(input[:spellcheck]).to eq('false')
      expect(input[:maxlength]).to eq(PersonalKeyFormatter.code_length.to_s)
      expect(input[:pattern]).to eq(PersonalKeyFormatter.regexp_string)
      expect(input[:class]).to include('personal-key', 'text-uppercase')
      expect(form.at_css("label[for='#{input[:id]}']").text)
        .to include(t('forms.personal_key.confirmation_label'))
      expect(form.at_css('button[type=submit]').text).to include(t('forms.buttons.continue'))
    end

    it 'keeps the reverify option and the cancel link to the account page' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[action='#{reactivate_account_path}'] " \
        "input[name='_method'][value='put']",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{reactivate_account_path}'] button.usa-button--tertiary",
        text: t('links.account.reactivate.without_key'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{account_path}']",
        text: t('links.cancel'),
      )
    end

    it 'renders an incorrect personal key error in the card' do
      flash[:error] = t('errors.messages.personal_key_incorrect')

      render

      expect(rendered).to have_css(
        '.auth--form-page .usa-alert--error',
        text: t('errors.messages.personal_key_incorrect'),
      )
    end

    context 'when the user is still signing up' do
      let(:user) { create(:user) }

      it 'cancels account creation instead' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button--tertiary[href='#{sign_up_cancel_path}']",
          text: t('links.cancel_account_creation'),
        )
      end
    end
  end
end
