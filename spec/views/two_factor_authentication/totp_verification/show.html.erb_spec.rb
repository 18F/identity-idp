require 'rails_helper'

RSpec.describe 'two_factor_authentication/totp_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_authentication_app) }
  let(:presenter_data) do
    attributes_for(:generic_otp_presenter).merge(
      two_factor_authentication_method: 'authenticator',
    )
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    @presenter = TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(
      data: presenter_data, view: ActionController::Base.new.view_context, service_provider: nil,
    )
    allow(@presenter).to receive(:reauthn).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.enter_2fa_code.security_code'))

    render
  end

  context 'in the default layout' do
    before do
      render
    end

    it_behaves_like 'an otp form'

    it 'uses numeric input mode (to allow leading zeroes)' do
      render

      code_input = Nokogiri::HTML(rendered).at_css('input#code')
      expect(code_input[:inputmode]).to eq('numeric')
    end

    it 'shows the correct header' do
      expect(rendered).to have_content t('two_factor_authentication.totp_header_text')
    end

    it 'shows the correct help text' do
      expect(rendered).to have_content 'Enter the code from your authenticator app.'
      expect(rendered).to have_content "enter the code corresponding to #{APP_NAME}"
    end

    it 'allows the user to fallback to SMS and voice' do
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
    end

    it 'provides an option to use a personal key' do
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'user is reauthenticating' do
      before do
        allow(@presenter).to receive(:reauthn).and_return(true)
        render
      end

      it 'provides a cancel link to return to profile' do
        expect(rendered).to have_link(
          t('links.cancel'),
          href: account_path,
        )
      end

      it 'renders the reauthn partial' do
        expect(view).to render_template(
          partial: 'two_factor_authentication/totp_verification/_reauthn',
        )
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the authentication app heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.totp_header_text'),
      )
    end

    it 'renders a gated form posting the code to the authenticator path' do
      render

      expect(rendered).to have_css(
        "form[action='#{login_two_factor_authenticator_path}'][data-nds-submit-gate]",
      )
    end

    it 'renders a required numeric one-time code input' do
      render

      code_input = Nokogiri::HTML(rendered).at_css('.auth__form-page-body input#code')
      expect(code_input[:name]).to eq('code')
      expect(code_input[:inputmode]).to eq('numeric')
      expect(code_input[:autocomplete]).to eq('one-time-code')
      expect(code_input[:pattern]).to eq("[0-9]{#{TwoFactorAuthenticatable::OTP_LENGTH}}")
      expect(code_input[:maxlength]).to eq(TwoFactorAuthenticatable::OTP_LENGTH.to_s)
      expect(code_input.key?('required')).to eq(true)
      expect(rendered).to have_css(
        '.auth__form-page-body .usa-input__floating-label',
        text: t('components.one_time_code_input.label'),
      )
    end

    it 'renders the remember-device checkbox in a card' do
      render

      expect(rendered).to have_css(
        '.auth__form-page-body .card input[type=checkbox][name=remember_device].checkbox__input',
      )
      expect(rendered).to have_css(
        '#remember-browser-description',
        text: t('nds.mfa.remember_device_info'),
      )
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

    it 'renders the authenticator troubleshooting options' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_link(
        t('instructions.mfa.authenticator.issues_with_authenticator'),
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

    it 'does not render the legacy authenticator instructions' do
      render

      expect(rendered).to_not have_content(
        strip_tags(t('instructions.mfa.authenticator.confirm_code_html', app_name_html: APP_NAME)),
      )
    end

    context 'user is reauthenticating' do
      before do
        allow(@presenter).to receive(:reauthn).and_return(true)
      end

      it 'renders the reauthn partial and cancels back to the account page' do
        render

        expect(view).to render_template(
          partial: 'two_factor_authentication/totp_verification/_reauthn',
        )
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'when the invalid one-time code flash is present' do
      before { flash[:error] = t('two_factor_authentication.invalid_otp') }

      it 'renders a titled error alert with the NDS heading and body copy' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__heading',
          text: t('nds.otp_verification.invalid_otp_heading'),
        )
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__text',
          text: t('nds.totp_verification.invalid_code_body'),
        )
        expect(rendered).to_not have_content(t('nds.otp_verification.invalid_otp_body'))
        expect(rendered).to have_css('.usa-alert--error', count: 1)
      end
    end

    context 'when a code is prefilled' do
      before { assign(:code, '123456') }

      it 'pre-populates the code input' do
        render

        expect(rendered).to have_css('input#code[value="123456"]')
      end
    end
  end
end
