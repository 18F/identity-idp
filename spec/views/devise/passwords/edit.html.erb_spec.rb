require 'rails_helper'

RSpec.describe 'devise/passwords/edit.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    user = build_stubbed(:user, :fully_registered)
    @reset_password_form = ResetPasswordForm.new(user: user)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.passwords.change'))

    render
  end

  context 'in the default layout' do
    it 'has a localized header' do
      render

      expect(rendered).to have_selector('h1', text: t('headings.passwords.change'))
    end

    it 'has localized phishing warning' do
      render

      expect(rendered).to have_selector('p', text: t('users.edit_info.warning'))
    end

    it 'sets form autocomplete to off' do
      render

      expect(rendered).to have_xpath("//form[@autocomplete='off']")
    end

    it 'has information about the password key' do
      render

      expect(rendered).to have_selector('p', text: t('instructions.password.password_key'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      @forbidden_passwords = ['forbidden']
    end

    it 'has a title matching the new password heading' do
      expect(view).to receive(:title=).with(t('nds.reset_password.heading'))

      render
    end

    it 'renders the form-page card with the new password heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.reset_password.heading'))
      expect(rendered).to_not have_content(t('headings.passwords.change'))
    end

    it 'includes the phishing warning and fraud help link in the intro' do
      render

      expect(rendered).to have_css('.auth__intro-description', text: t('nds.passwords.new.info'))
      expect(rendered).to have_css('.auth__intro-description', text: t('users.edit_info.warning'))
      expect(rendered).to have_css(
        ".auth__intro-description a[target='_blank'][href='#{help_center_redirect_path(
          category: 'fraud-concerns', article: 'overview',
        )}']",
        text: t('users.edit_info.link'),
      )
    end

    it 'renders a gated form putting the new password to the reset password path' do
      render

      form = Nokogiri::HTML(rendered).at_css(
        ".auth__form-page-body form[action='#{user_password_path}'][data-nds-submit-gate]",
      )
      expect(form[:method]).to eq('post')
      expect(form[:autocomplete]).to eq('off')
      expect(form.at_css('input[name=_method]')[:value]).to eq('put')
      expect(form.at_css('input[type=hidden][name="reset_password_form[reset_password_token]"]'))
        .to be_present
    end

    it 'renders the password and confirmation inputs' do
      render

      password = Nokogiri::HTML(rendered).at_css('input#reset_password_form_password')
      expect(password[:type]).to eq('password')
      expect(password[:name]).to eq('reset_password_form[password]')
      expect(password[:autocomplete]).to eq('new-password')
      expect(password[:'aria-describedby'].split).to include('password-description')
      expect(password.key?('required')).to eq(true)

      confirmation = Nokogiri::HTML(rendered).at_css(
        'input#reset_password_form_password_confirmation',
      )
      expect(confirmation[:type]).to eq('password')
      expect(confirmation[:name]).to eq('reset_password_form[password_confirmation]')
      expect(confirmation.key?('required')).to eq(true)

      expect(rendered).to have_css('.usa-input__floating-label', text: t('forms.password'))
      expect(rendered).to have_css(
        '.usa-input__floating-label',
        text: t('components.password_confirmation.confirm_label'),
      )
      expect(rendered).to_not have_css('.usa-input__error--visible')
    end

    it 'renders the NDS password strength meter with the forbidden passwords' do
      render

      meter = Nokogiri::HTML(rendered).at_css('lg-nds-password-strength')
      expect(meter).to be_present
      expect(meter.to_html).to include('reset_password_form_password')
      expect(meter.to_html).to include('forbidden')
    end

    it 'submits with a Continue primary button' do
      render

      expect(rendered).to have_button(t('forms.buttons.continue'))
      expect(rendered).to_not have_button(t('forms.passwords.edit.buttons.submit'))
    end

    it 'renders the personal key callout described by the password input' do
      render

      expect(rendered).to have_css(
        '.usa-alert--info#password-description',
        text: t('nds.reset_password.personal_key_info'),
      )
      expect(rendered).to_not have_content(t('instructions.password.password_key'))
    end

    it 'does not render the legacy password accordion' do
      render

      expect(rendered).to_not have_content(t('instructions.password.help_text_header'))
    end

    context 'with a password error' do
      before do
        @reset_password_form.errors.add(:password, :pwned_password)
      end

      it 'shows the error on the password input' do
        render

        expect(rendered).to have_css(
          '.usa-input__error--visible',
          text: t('errors.messages.pwned_password'),
        )
        expect(rendered).to have_css('input#reset_password_form_password[aria-invalid="true"]')
      end
    end

    context 'with mismatched passwords' do
      before do
        @reset_password_form.errors.add(
          :password_confirmation,
          t('errors.messages.password_mismatch'),
        )
      end

      it 'shows the error on the confirmation input' do
        render

        expect(rendered).to have_css(
          '.usa-input__error--visible',
          text: t('errors.messages.password_mismatch'),
        )
        expect(rendered).to have_css(
          'input#reset_password_form_password_confirmation[aria-invalid="true"]',
        )
      end
    end
  end
end
