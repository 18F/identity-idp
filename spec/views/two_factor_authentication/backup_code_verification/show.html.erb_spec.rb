require 'rails_helper'

RSpec.describe 'two_factor_authentication/backup_code_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_backup_code) }
  let(:remember_device_default) { false }
  let(:backup_code_form) { BackupCodeVerificationForm.new(user:, request: controller.request) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    @presenter = TwoFactorAuthCode::BackupCodePresenter.new(
      view: view,
      data: { current_user: user },
      service_provider: nil,
      remember_device_default:,
    )
    @backup_code_form = backup_code_form
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('two_factor_authentication.backup_code_header_text'))

    render
  end

  context 'in the default layout' do
    it 'renders the heading and prompt' do
      render

      expect(rendered).to have_css(
        'h1',
        text: t('two_factor_authentication.backup_code_header_text'),
      )
      expect(rendered).to have_content(t('two_factor_authentication.backup_code_prompt'))
    end

    it 'renders the backup code field posting to the backup code path' do
      render

      expect(rendered).to have_css("form[action='#{login_two_factor_backup_code_path}']")
      code_input = Nokogiri::HTML(rendered).at_css('input[name="backup_code_verification_form[backup_code]"]')
      expect(code_input[:pattern]).to eq('^[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}$')
      expect(code_input[:maxlength]).to eq('14')
      expect(code_input[:class]).to include('backup-code')
    end

    it 'renders the remember-device checkbox and submit button' do
      render

      expect(rendered).to have_field(
        'backup_code_verification_form[remember_device]',
        type: :checkbox,
      )
      expect(rendered).to have_button(t('forms.buttons.submit.default'))
    end

    it 'renders the troubleshooting options and cancel link' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
      expect(rendered).to have_link(t('instructions.mfa.backup_code.issues_with_backup_codes'))
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
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

    it 'renders the form-page card with the backup code heading and prompt' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.backup_code_header_text'),
      )
      expect(rendered).to have_content(t('two_factor_authentication.backup_code_prompt'))
    end

    it 'renders a gated form posting to the backup code path' do
      render

      expect(rendered).to have_css(
        "form[action='#{login_two_factor_backup_code_path}'][method='post'][data-nds-submit-gate]",
      )
    end

    it 'renders the required backup code input with the legacy format rules' do
      render

      code_input = Nokogiri::HTML(rendered).at_css(
        '.auth__form-page-body input#backup_code_verification_form_backup_code',
      )
      expect(code_input[:name]).to eq('backup_code_verification_form[backup_code]')
      expect(code_input[:pattern]).to eq('^[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}-?[a-zA-Z0-9]{4}$')
      expect(code_input[:maxlength]).to eq('14')
      expect(code_input[:autocomplete]).to eq('off')
      expect(code_input[:autocapitalize]).to eq('none')
      expect(code_input[:spellcheck]).to eq('false')
      expect(code_input[:class]).to include('backup-code', 'text-uppercase')
      expect(code_input.key?('required')).to eq(true)
      expect(rendered).to have_css(
        '.auth__form-page-body .usa-input__floating-label',
        text: t('forms.two_factor.backup_code'),
      )
    end

    it 'renders the remember-device checkbox in a card' do
      render

      expect(rendered).to have_css(
        '.auth__form-page-body .card ' \
          'input[type=checkbox][name="backup_code_verification_form[remember_device]"]' \
          '.checkbox__input',
      )
      expect(rendered).to have_css(
        'input[type=hidden][name="backup_code_verification_form[remember_device]"][value="0"]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '#remember-browser-description',
        text: t('nds.mfa.remember_device_info'),
      )
      expect(rendered).to_not have_css(
        'input[name="backup_code_verification_form[remember_device]"][checked]',
      )
    end

    context 'when remembering the device by default' do
      let(:remember_device_default) { true }

      it 'checks the remember-device checkbox' do
        render

        expect(rendered).to have_css(
          'input[type=checkbox][name="backup_code_verification_form[remember_device]"][checked]',
        )
      end
    end

    it 'submits the code with a Continue primary button' do
      render

      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    it 'renders the choose-another-method tertiary button' do
      render

      expect(rendered).to have_css(
        ".auth__form-page-body .actions a.usa-button[href='#{login_two_factor_options_path}']",
        text: t('nds.mfa.choose_another_method'),
      )
    end

    it 'renders the backup code troubleshooting options in a new tab' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        "a[href='#{MarketingSite.help_center_article_url(
          category: 'trouble-signing-in',
          article: 'authentication/issues-with-backup-codes',
        )}'][target=_blank]",
        text: t('instructions.mfa.backup_code.issues_with_backup_codes'),
      )
      expect(rendered).to have_link(t('two_factor_authentication.add_or_change_authenticator'))
      expect(rendered).to_not have_link(t('two_factor_authentication.login_options_link_text'))
    end

    it 'provides a cancel button that signs the user out' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_out_path}']",
        text: t('links.cancel'),
      )
    end

    context 'when the user is signing up' do
      before { allow(view).to receive(:user_signing_up?).and_return(true) }

      it 'cancels account creation' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'when the backup code was invalid' do
      before do
        backup_code_form.errors.add(
          :backup_code,
          :invalid,
          message: t('two_factor_authentication.invalid_backup_code'),
        )
        flash[:error] = t('two_factor_authentication.invalid_backup_code')
      end

      it 'shows the error inline on the field instead of a flash alert' do
        render

        code_input = Nokogiri::HTML(rendered).at_css('input#backup_code_verification_form_backup_code')
        expect(code_input['aria-invalid']).to eq('true')
        expect(code_input['aria-describedby']).to include(
          'backup_code_verification_form_backup_code_nds_error',
        )
        expect(rendered).to have_css(
          '#backup_code_verification_form_backup_code_nds_error.usa-input__error--visible',
          text: t('two_factor_authentication.invalid_backup_code'),
        )
        expect(rendered).to_not have_css('.usa-alert--error')
      end
    end

    context 'when the flash error is not about the backup code' do
      before { flash[:error] = 'Something else went wrong.' }

      it 'leaves the flash for the form-page alert' do
        render

        expect(rendered).to have_css('.usa-alert--error', text: 'Something else went wrong.')
        expect(rendered).to_not have_css('.usa-input__error--visible')
      end
    end
  end
end
