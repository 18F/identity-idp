require 'rails_helper'

RSpec.describe 'devise/passwords/new.html.erb' do
  let(:sp) do
    build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com',
    )
  end
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @password_reset_email_form = PasswordResetEmailForm.new('')
    view_context = ActionController::Base.new.view_context
    allow(view_context).to receive(:new_user_session_url)
      .and_return('https://www.example.com/')
    allow(view_context).to receive(:sign_up_email_path)
      .and_return('/sign_up/enter_email')
    allow_any_instance_of(ActionController::TestRequest).to receive(:path)
      .and_return('/users/password/new')

    @decorated_sp_session = ServiceProviderSessionCreator.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    ).create_session
    allow(view).to receive(:decorated_sp_session).and_return(@decorated_sp_session)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.passwords.forgot'))

    render
  end

  context 'in the default layout' do
    it 'has a localized header' do
      render

      expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot'))
    end

    it 'sets form autocomplete to off' do
      render

      expect(rendered).to have_xpath("//form[@autocomplete='off']")
    end

    it 'sets input autocorrect to off' do
      render

      expect(rendered).to have_xpath("//input[@autocorrect='off']")
    end

    it 'has a cancel link that points to the decorated_sp_session cancel_link_url' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: @decorated_sp_session.cancel_link_url)
    end

    it 'has sp alert for certain service providers' do
      render

      expect(rendered).to have_selector(
        '.usa-alert',
        text: 'custom forgot password help text for Awesome Application!',
      )
    end

    it 'renders troubleshooting content' do
      render

      expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
      expect(rendered).to have_link(t('forms.passwords.reset.how_to_reset'))
      expect(rendered).to have_link(t('forms.passwords.reset.how_to_reset_with_personal_key'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    describe 'reCAPTCHA submit button' do
      before do
        allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(false)
      end

      context 'when password_reset_recaptcha_enabled? is true' do
        before do
          allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
            .and_return(true)
        end

        it 'renders the captcha submit button' do
          render

          expect(rendered).to have_css('lg-captcha-submit-button')
        end
      end

      context 'when password_reset_recaptcha_enabled? is false' do
        before do
          allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
            .and_return(false)
        end

        it 'renders a plain submit button with no captcha' do
          render

          expect(rendered).to have_button(t('forms.buttons.continue'))
          expect(rendered).to_not have_css('lg-captcha-submit-button')
        end

        it 'still renders the captcha when the mock validator is enabled' do
          allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(true)

          render

          expect(rendered).to have_css('lg-captcha-submit-button')
        end
      end
    end

    context 'service provider does not have custom help text' do
      let(:sp) do
        build_stubbed(
          :service_provider_without_help_text,
          friendly_name: 'Awesome Application!',
          return_to_sp_url: 'www.awesomeness.com',
        )
      end

      it 'does not have an sp alert for service providers without alert messages' do
        render

        expect(rendered).to_not have_selector('.usa-alert--info')
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the enter-email heading' do
      expect(view).to receive(:title=).with(t('nds.reset_password.email_heading'))

      render
    end

    it 'renders the form-page card with the enter-email heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('nds.reset_password.email_heading'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('instructions.password.forgot'),
      )
      expect(rendered).to_not have_content(t('headings.passwords.forgot'))
    end

    it 'renders a gated form posting the email to the reset password path' do
      render

      expect(rendered).to have_css(
        "form[action='#{user_password_path}'][method='post'][data-nds-submit-gate]",
      )
    end

    it 'renders the floating-label email input' do
      render

      input = Nokogiri::HTML(rendered).at_css(
        '.auth__form-page-body input#password_reset_email_form_email',
      )
      expect(input[:name]).to eq('password_reset_email_form[email]')
      expect(input[:type]).to eq('email')
      expect(input[:autocorrect]).to eq('off')
      expect(input.key?('required')).to eq(true)
      expect(rendered).to have_css(
        '.auth__form-page-body .usa-input__floating-label',
        text: t('account.index.email_short'),
      )
      expect(rendered).to_not have_css('.usa-input__error--visible')
    end

    it 'has sp alert for certain service providers' do
      render

      expect(rendered).to have_css(
        '.auth__form-page-body .usa-alert',
        text: 'custom forgot password help text for Awesome Application!',
      )
    end

    it 'renders the troubleshooting options as new-tab tertiary buttons' do
      render

      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[target='_blank'][href='#{help_center_redirect_path(
          category: 'trouble-signing-in', article: 'forgot-your-password',
        )}']",
        text: t('forms.passwords.reset.how_to_reset'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[target='_blank'][href='#{help_center_redirect_path(
          category: 'trouble-signing-in',
          article: 'forgot-your-personal-key',
          article_anchor: 'if-you-have-a-personal-key',
        )}']",
        text: t('forms.passwords.reset.how_to_reset_with_personal_key'),
      )
    end

    it 'renders a cancel button that points to the decorated_sp_session cancel_link_url' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{@decorated_sp_session.cancel_link_url}']",
        text: t('links.cancel'),
      )
    end

    describe 'reCAPTCHA submit button' do
      before do
        allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(false)
      end

      context 'when password_reset_recaptcha_enabled? is true' do
        before do
          allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
            .and_return(true)
        end

        it 'renders the captcha submit button with the send link label' do
          render

          expect(rendered).to have_css(
            "lg-captcha-submit-button[recaptcha-action='#{PasswordResetRecaptchaForm::RECAPTCHA_ACTION}']",
          )
          expect(rendered).to have_button(t('forms.buttons.send_link'))
        end
      end

      context 'when password_reset_recaptcha_enabled? is false' do
        before do
          allow(FeatureManagement).to receive(:password_reset_recaptcha_enabled?)
            .and_return(false)
        end

        it 'renders a plain send link submit button with no captcha' do
          render

          expect(rendered).to have_button(t('forms.buttons.send_link'))
          expect(rendered).to_not have_button(t('forms.buttons.continue'))
          expect(rendered).to_not have_css('lg-captcha-submit-button')
        end

        it 'still renders the captcha when the mock validator is enabled' do
          allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(true)

          render

          expect(rendered).to have_css('lg-captcha-submit-button')
        end
      end
    end

    context 'with an invalid email' do
      before do
        @password_reset_email_form.errors.add(
          :email,
          t('valid_email.validations.email.invalid'),
        )
      end

      it 'shows the error on the email input' do
        render

        expect(rendered).to have_css(
          '.usa-input__error--visible',
          text: t('valid_email.validations.email.invalid'),
        )
        expect(rendered).to have_css('input#password_reset_email_form_email[aria-invalid="true"]')
      end
    end

    context 'after an invalid reset link' do
      before { flash[:error] = t('devise.passwords.invalid_token') }

      it 'renders a titled error alert asking for a new link' do
        render

        expect(rendered).to have_css(
          '.usa-alert--error .usa-alert__heading',
          text: t('nds.reset_password.invalid_token_heading'),
        )
        expect(rendered).to have_css(
          '.usa-alert--error',
          text: t('nds.reset_password.request_new_link'),
        )
        expect(rendered).to_not have_content(t('devise.passwords.invalid_token'))
      end
    end

    context 'after an expired reset link' do
      before { flash[:error] = t('devise.passwords.token_expired') }

      it 'renders a titled error alert asking for a new link' do
        render

        expect(rendered).to have_css(
          '.usa-alert--error .usa-alert__heading',
          text: t('nds.reset_password.token_expired_heading'),
        )
        expect(rendered).to_not have_content(t('devise.passwords.token_expired'))
      end
    end

    context 'with another error flash' do
      before { flash[:error] = 'Something else went wrong.' }

      it 'leaves the flash to the form page' do
        render

        expect(rendered).to have_content('Something else went wrong.')
        expect(rendered).to_not have_css('.usa-alert__heading')
      end
    end
  end
end
