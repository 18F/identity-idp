require 'rails_helper'

RSpec.describe 'two_factor_authentication/webauthn_verification/show.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:platform_authenticator) { false }
  let(:auto_prompt) { false }
  let(:reauthn) { false }
  let(:credentials) { [{ id: 'credential-id', transports: ['usb'] }] }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_session).and_return({ webauthn_challenge: [1, 2, 3] })
    allow(view).to receive(:sp_session).and_return({})
    @presenter = TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
      view:,
      data: { credentials:, reauthn: },
      service_provider: nil,
      platform_authenticator:,
      auto_prompt:,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.present_webauthn'))

    render
  end

  context 'in the default layout' do
    it 'includes a page title for webauthn authenticator' do
      expect(view).to receive(:title=).with(t('titles.present_webauthn'))

      render
    end

    it 'includes hidden platform form input with value false' do
      expect(rendered).to have_field('platform', with: 'false', type: 'hidden')
    end

    it 'includes troubleshooting link to use another authentication method' do
      expect(rendered).to have_css('.troubleshooting-options li', count: 3)
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: login_two_factor_options_path,
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the verify button with the legacy spacing classes' do
      expect(rendered).to have_css(
        'button.webauthn-verify-button__button.display-block.margin-y-3',
        text: t('two_factor_authentication.webauthn_use_key'),
      )
    end

    context 'when auto prompt is enabled' do
      let(:auto_prompt) { true }

      it 'adds the auto prompt dataset to the webauthn button element' do
        expect(rendered).to have_css('lg-webauthn-verify-button[data-auto-prompt="true"]')
      end
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it 'includes a page title for a platform authenticator' do
        expect(view).to receive(:title=).with(
          t('two_factor_authentication.webauthn_platform_header_text'),
        )

        render
      end

      it 'includes hidden platform form input with value false' do
        expect(rendered).to have_field('platform', with: 'true', type: 'hidden')
      end

      it 'includes troubleshooting link to learn more about face/touch unlock' do
        expect(rendered).to have_css('.troubleshooting-options li', count: 3)
        expect(rendered).to have_link(
          t('instructions.mfa.webauthn_platform.issues_with_ft_unlock'),
          href: help_center_redirect_path(
            category: 'trouble-signing-in',
            article: 'face-or-touch-unlock',
            flow: :two_factor_authentication,
            step: :webauthn_verification,
          ),
        )
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the security key heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('headings.webauthn_setup.new'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.webauthn_verification.roaming_intro'),
      )
    end

    it 'renders the webauthn form patching the webauthn path' do
      expect(rendered).to have_css(
        "form#webauthn-form[action='#{login_two_factor_webauthn_path}'][method=post]",
      )
      expect(rendered).to have_css(
        'form#webauthn-form input[name=_method][value=patch]',
        visible: :all,
      )
    end

    it 'includes hidden platform form input with value false' do
      expect(rendered).to have_field('platform', with: 'false', type: 'hidden')
    end

    it 'renders the webauthn verify button with credentials, challenge and hidden inputs' do
      button = Nokogiri::HTML(rendered).at_css('form#webauthn-form lg-webauthn-verify-button')
      expect(button['data-credentials']).to eq(credentials.to_json)
      expect(button['data-user-challenge']).to eq([1, 2, 3].to_json)
      expect(button['data-auto-prompt']).to be_nil
      %w[credential_id authenticator_data signature client_data_json webauthn_error
         screen_lock_error].each do |name|
        expect(rendered).to have_field(name, type: 'hidden')
      end
      expect(rendered).to have_css(
        'lg-webauthn-verify-button .webauthn-verify-button__spinner[hidden]',
        visible: :all,
      )
    end

    context 'with a security key' do
      it 'submits with a Continue primary button' do
        expect(rendered).to have_css(
          'lg-webauthn-verify-button button.webauthn-verify-button__button[type=submit]',
          text: t('forms.buttons.continue'),
        )
        expect(rendered).to_not have_css('button.webauthn-verify-button__button.margin-y-3')
      end
    end

    it 'renders the remember-device checkbox in a card' do
      expect(rendered).to have_css(
        '.auth__form-page-body .card input[type=checkbox][name=remember_device].checkbox__input',
      )
      expect(rendered).to have_css(
        'input[type=hidden][name=remember_device][value="0"]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '#remember-browser-description',
        text: t('nds.mfa.remember_device_info'),
      )
    end

    it 'renders the choose-another-method tertiary button' do
      expect(rendered).to have_css(
        ".auth__form-page-body .actions a.usa-button[href='#{login_two_factor_options_path}']",
        text: t('nds.mfa.choose_another_method'),
      )
    end

    it 'renders the security key troubleshooting options' do
      expect(rendered).to have_css(
        '.auth__actions .nds-troubleshooting-options h2',
        text: t('components.troubleshooting_options.default_heading'),
      )
      expect(rendered).to have_link(
        t('instructions.mfa.webauthn.issues_with_security_key'),
        href: MarketingSite.help_center_article_url(
          category: 'trouble-signing-in',
          article: 'authentication/issues-with-security-keys',
        ),
      )
      expect(rendered).to have_link(t('two_factor_authentication.add_or_change_authenticator'))
      expect(rendered).to_not have_link(t('two_factor_authentication.login_options_link_text'))
    end

    it 'provides a cancel button that signs the user out' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_out_path}']",
        text: t('links.cancel'),
      )
    end

    it 'does not render the legacy heading or instructions' do
      expect(rendered).to_not have_content(t('two_factor_authentication.webauthn_header_text'))
      expect(rendered).to_not have_content(t('instructions.mfa.webauthn.confirm_webauthn'))
    end

    context 'when auto prompt is enabled' do
      let(:auto_prompt) { true }

      it 'adds the auto prompt dataset to the webauthn button element' do
        expect(rendered).to have_css('lg-webauthn-verify-button[data-auto-prompt="true"]')
      end
    end

    context 'when the user is reauthenticating' do
      let(:reauthn) { true }

      it 'cancels back to the account page' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'when the user is signing up' do
      before { allow(view).to receive(:user_signing_up?).and_return(true) }

      it 'cancels to the sign-up cancel page' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'when a security key error flash is present' do
      before do
        flash[:error] = t(
          'two_factor_authentication.webauthn_error.connect_html',
          link_html: link_to(
            t('two_factor_authentication.webauthn_error.additional_methods_link'),
            login_two_factor_options_path,
          ),
        )
      end

      it 'renders one titled error alert with the legacy message' do
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__heading',
          text: t('nds.webauthn_verification.roaming_error_heading'),
        )
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert--error .usa-alert__text',
          text: t(
            'two_factor_authentication.webauthn_error.connect_html',
            link_html: t('two_factor_authentication.webauthn_error.additional_methods_link'),
          ),
        )
        expect(rendered).to have_css('.usa-alert--error', count: 1)
        expect(rendered).to have_css(
          ".usa-alert--error a[href='#{login_two_factor_options_path}']",
          text: t('two_factor_authentication.webauthn_error.additional_methods_link'),
        )
      end
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }
      let(:credentials) { [{ id: 'credential-id', transports: ['internal', 'hybrid'] }] }

      it 'keeps the legacy platform page title' do
        expect(view).to receive(:title=).with(
          t('two_factor_authentication.webauthn_platform_header_text'),
        )

        render
      end

      it 'renders the passkey heading and intro' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.webauthn_verification.platform_heading'),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: t('nds.webauthn_verification.platform_intro'),
        )
      end

      it 'includes hidden platform form input with value true' do
        expect(rendered).to have_field('platform', with: 'true', type: 'hidden')
      end

      it 'submits with a Use passkey primary button' do
        expect(rendered).to have_css(
          'lg-webauthn-verify-button button.webauthn-verify-button__button[type=submit]',
          text: t('nds.webauthn_verification.platform_button'),
        )
      end

      it 'renders the face or touch unlock troubleshooting link' do
        expect(rendered).to have_link(
          t('instructions.mfa.webauthn_platform.issues_with_ft_unlock'),
          href: help_center_redirect_path(
            category: 'trouble-signing-in',
            article: 'face-or-touch-unlock',
            flow: :two_factor_authentication,
            step: :webauthn_verification,
          ),
        )
        expect(rendered).to_not have_link(t('two_factor_authentication.login_options_link_text'))
      end

      context 'when a passkey error flash is present' do
        before do
          flash[:error] = t(
            'two_factor_authentication.webauthn_error.try_again',
            link: link_to(
              t('two_factor_authentication.webauthn_error.additional_methods_link'),
              login_two_factor_options_path,
            ),
          )
        end

        it 'renders a titled passkey error alert' do
          expect(rendered).to have_css(
            '.auth--form-page .usa-alert--error .usa-alert__heading',
            text: t('nds.webauthn_verification.platform_error_heading'),
          )
          expect(rendered).to have_css(
            ".usa-alert--error a[href='#{login_two_factor_options_path}']",
            text: t('two_factor_authentication.webauthn_error.additional_methods_link'),
          )
          expect(rendered).to have_css('.usa-alert--error', count: 1)
        end
      end
    end
  end
end
