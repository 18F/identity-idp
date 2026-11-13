require 'rails_helper'

RSpec.describe 'two_factor_authentication/personal_key_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
    @personal_key_form = PersonalKeyForm.new(user)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.enter_2fa_code.security_code'))

    render
  end

  context 'in the default layout' do
    it_behaves_like 'an otp form'

    it 'has a localized heading' do
      render

      expect(rendered)
        .to have_content t('two_factor_authentication.personal_key_header_text')
    end

    it 'prompts the user to enter their personal key' do
      render

      expect(rendered)
        .to have_content t('two_factor_authentication.personal_key_prompt')
    end

    it 'contains a form to submit the personal key' do
      render

      expect(rendered).to have_button(t('forms.buttons.submit.default'))
      expect(rendered)
        .to have_xpath("//form[@action='#{login_two_factor_personal_key_path}']")
      expect(rendered)
        .to have_xpath("//form[@method='post']")
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'when the personal key deprecation warning is shown' do
      before { @show_deprecation_warning = true }

      it 'renders a warning alert with the deprecation message' do
        render

        expect(rendered).to have_selector('.usa-alert--warning')
        expect(rendered)
          .to have_content(t('two_factor_authentication.personal_key_deprecation_warning'))
      end
    end

    context 'when the personal key deprecation warning is not shown' do
      before { @show_deprecation_warning = false }

      it 'does not render a warning alert' do
        render

        expect(rendered).to_not have_selector('.usa-alert--warning')
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the personal key heading and prompt' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.personal_key_header_text'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.personal_key_verification.prompt'),
      )
      expect(rendered).to_not have_content(t('two_factor_authentication.personal_key_prompt'))
      expect(rendered).to_not have_content('provided a new key')
    end

    it 'renders a gated form posting the personal key' do
      render

      expect(rendered).to have_css(
        "form[action='#{login_two_factor_personal_key_path}'][method='post'][data-nds-submit-gate]",
      )
    end

    it 'renders the formatted personal key input' do
      render

      word_count = IdentityConfig.store.recovery_code_length
      input = Nokogiri::HTML(rendered).at_css(
        '.auth__form-page-body input#personal_key_form_personal_key',
      )
      expect(input[:name]).to eq('personal_key_form[personal_key]')
      expect(input[:class].split).to include('personal-key', 'text-uppercase')
      expect(input[:autocapitalize]).to eq('none')
      expect(input[:autocomplete]).to eq('off')
      expect(input[:spellcheck]).to eq('false')
      expect(input[:maxlength])
        .to eq(((RandomPhrase::WORD_LENGTH * word_count) + (word_count - 1)).to_s)
      expect(input.key?('required')).to eq(true)
      expect(rendered).to have_css(
        '.auth__form-page-body .usa-input__floating-label',
        text: t('forms.two_factor.personal_key'),
      )
    end

    it 'submits the personal key with a Continue primary button' do
      render

      expect(rendered).to have_button(t('forms.buttons.continue'))
      expect(rendered).to_not have_button(t('forms.buttons.submit.default'))
    end

    it 'renders the choose-another-method tertiary button' do
      render

      expect(rendered).to have_css(
        ".auth__form-page-body .actions a.usa-button[href='#{login_two_factor_options_path}']",
        text: t('nds.mfa.choose_another_method'),
      )
    end

    it 'renders the remaining troubleshooting options' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_link(
        t('two_factor_authentication.learn_more'),
        href: help_center_redirect_path(
          category: 'get-started',
          article: 'authentication-methods',
          flow: :two_factor_authentication,
          step: :personal_key_verification,
        ),
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

    it 'does not render a deprecation warning by default' do
      render

      expect(rendered).to_not have_selector('.usa-alert--warning')
    end

    context 'when the user is signing up' do
      before { allow(view).to receive(:user_signing_up?).and_return(true) }

      it 'cancels account creation' do
        render

        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel_account_creation'),
        )
      end
    end

    context 'when the personal key deprecation warning is shown' do
      before { @show_deprecation_warning = true }

      it 'renders the deprecation warning alongside a prompt that promises no new key' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--warning',
          text: t('two_factor_authentication.personal_key_deprecation_warning'),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: t('nds.personal_key_verification.prompt'),
        )
        expect(rendered).to_not have_content('provided a new key')
      end
    end

    context 'when the invalid personal key flash is present' do
      before { flash[:error] = t('two_factor_authentication.invalid_personal_key') }

      it 'renders a titled error alert with the NDS heading and body copy' do
        render

        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__heading',
          text: t('nds.personal_key_verification.invalid_heading'),
        )
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__text',
          text: t('nds.personal_key_verification.invalid_body'),
        )
        expect(rendered).to have_css('.usa-alert--error', count: 1)
      end
    end
  end
end
