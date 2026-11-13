require 'rails_helper'

RSpec.describe 'users/webauthn_setup/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  let(:platform_authenticator) { true }
  let(:passkey_upsell) { false }

  let(:user_session) do
    { webauthn_challenge: 'fake_challenge' }
  end
  let(:presenter) do
    WebauthnSetupPresenter.new(
      current_user: user,
      user_fully_authenticated: true,
      user_opted_remember_device_cookie: true,
      remember_device_default: true,
      platform_authenticator: platform_authenticator,
      url_options: {},
      passkey_upsell: passkey_upsell,
    )
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:in_account_creation_flow?).and_return(false)
    allow(view).to receive(:enabled_mfa_methods_count).and_return(1)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
    allow(view).to receive(:mobile?).and_return(false)
    assign(:account_creation_threatmetrix, { threatmetrix_session_id: nil })
    assign(:platform_authenticator, platform_authenticator)
    assign(:user_session, user_session)
    assign(:presenter, presenter)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(presenter.page_title)

    render
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'webauthn platform' do
      let(:platform_authenticator) { true }

      it 'does not display the form' do
        render
        expect(rendered).to_not have_content(
          t('two_factor_authentication.two_factor_choice_options.webauthn'),
        )
      end

      context 'when user selects multiple MFA options on account creation' do
        before do
          assign(:need_to_set_up_additional_mfa, false)
        end

        it 'does not displays info alert' do
          render

          expect(rendered).to_not have_content(t('forms.webauthn_platform_setup.info_text'))
        end
      end

      context 'when user selects only platform auth options on account creation' do
        before do
          assign(:need_to_set_up_additional_mfa, true)
        end

        it 'displays info alert' do
          render

          expect(rendered).to have_content(t('forms.webauthn_platform_setup.info_text'))
        end
      end

      context 'when user is adding MFA at accounts page' do
        before do
          assign(:need_to_set_up_additional_mfa, false)
        end

        it 'does not displays info alert' do
          render

          expect(rendered).to_not have_content(t('forms.webauthn_platform_setup.info_text'))
        end
      end
    end

    context 'non-platform webauthn' do
      let(:platform_authenticator) { false }

      it 'displays the form' do
        render

        expect(rendered).to have_content(
          t('two_factor_authentication.two_factor_choice_options.webauthn').downcase,
        )
      end

      it 'links to help screen' do
        render

        expect(rendered).to have_link(
          t('forms.webauthn_setup.learn_more'),
          href: help_center_redirect_path(
            category: 'get-started',
            article: 'authentication-methods',
            article_anchor: 'security-key',
            flow: :two_factor_authentication,
            step: :security_key_setup,
          ),
        )
      end

      it 'displays the step 1 heading' do
        render

        expect(rendered).to have_css('h2', text: t('forms.webauthn_setup.step_1'))
      end

      it 'displays the step 2 heading' do
        render

        expect(rendered).to have_css('h2', text: t('forms.webauthn_setup.step_2'))
      end

      it 'displays the step 3 heading' do
        render

        expect(rendered).to have_css('h2', text: t('forms.webauthn_setup.step_3'))
      end

      it 'displays the nickname input field' do
        render

        expect(rendered).to have_selector("input#nickname[type='text']")
      end

      it 'displays form submission button' do
        render

        expect(rendered).to have_button(t('forms.webauthn_setup.set_up'))
      end

      describe 'security key image' do
        it 'displays the security key image' do
          render

          expect(rendered).to have_css('svg')
        end

        context 'when on a mobile device' do
          before do
            allow(view).to receive(:mobile?).and_return(true)
          end

          it 'displays the mobile security key image' do
            render

            expect(rendered).to have_css('svg.security-key--mobile')
          end
        end
      end
    end
  end

  context 'in the NDS layout' do
    let(:in_account_creation_flow) { false }
    let(:in_multi_mfa_selection_flow) { false }
    let(:enabled_mfa_methods_count) { 1 }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(in_multi_mfa_selection_flow)
      allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
    end

    it 'renders the form-page card inside the WebAuthn form' do
      render

      expect(rendered).to have_selector(
        'form#webauthn-form[data-nds-submit-gate] section.auth.auth--form-page',
      )
    end

    it 'keeps every hidden field the WebAuthn script reads and posts' do
      render

      %w[
        user_id user_email user_challenge exclude_credentials webauthn_id attestation_object
        client_data_json authenticator_data_value transports platform_authenticator
      ].each do |id|
        expect(rendered).to have_field(id, type: :hidden)
      end
      expect(rendered).to have_field('user_email', type: :hidden, with: user.email)
      expect(rendered).to have_field('_method', type: :hidden, with: 'patch')
    end

    it 'renders the saving spinner hidden' do
      render

      expect(rendered).to have_selector('#spinner[hidden]', visible: :all)
      expect(rendered).to have_content(t('forms.webauthn_setup.saving'))
    end

    it 'renders the remember-browser checkbox in a card' do
      render

      expect(rendered).to have_selector(
        '.card input#remember_device[type=checkbox]' \
        '[aria-describedby="remember-browser-description"]',
      )
      expect(rendered).to have_selector(
        '#remember-browser-description',
        text: t('nds.mfa.remember_device_info'),
      )
    end

    it 'does not emit the account-creation stepper outside account creation' do
      render

      expect(view.content_for(:nds_header_progress)).to be_blank
    end

    context 'when adding a first method during account creation' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 0 }

      it 'emits the Security stepper on the first substep' do
        render

        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css('.progress__step[aria-current="step"]', text: 'Security')
        expect(progress).to have_content('1 / 2')
      end
    end

    context 'when adding a second method during account creation' do
      let(:in_account_creation_flow) { true }
      let(:enabled_mfa_methods_count) { 1 }

      it 'emits the Security stepper on the second substep' do
        render

        expect(view.content_for(:nds_header_progress)).to have_content('2 / 2')
      end
    end

    context 'when adding a method from the account page' do
      it 'offers Cancel back to the account page' do
        render

        expect(rendered).to have_selector(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('links.cancel'),
        )
        expect(rendered).to_not have_link(t('nds.mfa.choose_another_method'))
      end
    end

    context 'when selecting methods during setup' do
      let(:in_multi_mfa_selection_flow) { true }

      it 'offers Choose another method back to the method list' do
        render

        expect(rendered).to have_selector(
          ".auth__actions a.usa-button[href='#{authentication_methods_setup_path}']",
          text: t('nds.mfa.choose_another_method'),
        )
        expect(rendered).to_not have_link(t('links.cancel'))
      end
    end

    context 'when the setup returns an error' do
      before do
        flash[:error] = t('errors.webauthn_setup.not_supported')
      end

      it 'renders the error inside the card' do
        render

        expect(rendered).to have_selector(
          '.auth--form-page .usa-alert--error',
          text: t('errors.webauthn_setup.not_supported'),
        )
      end
    end

    context 'webauthn platform' do
      let(:platform_authenticator) { true }

      it 'renders the Add passkey heading and the platform intro' do
        render

        expect(rendered).to have_selector('h1', count: 1)
        expect(rendered).to have_selector('h1', text: t('nds.webauthn_setup.platform_heading'))
        expect(rendered).to have_link(
          t('forms.webauthn_platform_setup.intro_link_text'),
          href: help_center_redirect_path(
            category: 'trouble-signing-in',
            article: 'face-or-touch-unlock',
            flow: :two_factor_authentication,
            step: :webauthn_setup,
          ),
        )
      end

      it 'posts to the platform setup path' do
        render

        expect(rendered).to have_selector(
          "form#webauthn-form[action='#{webauthn_setup_path(platform: true)}']",
        )
        expect(rendered).to have_field('platform_authenticator', type: :hidden, with: 'true')
      end

      it 'does not render the security key steps or nickname field' do
        render

        expect(rendered).to_not have_field('nickname')
        expect(rendered).to_not have_content(t('forms.webauthn_setup.step_1'))
      end

      it 'renders the Continue button' do
        render

        expect(rendered).to have_button(t('forms.webauthn_platform_setup.continue'))
      end

      it 'does not render the info alert by default' do
        render

        expect(rendered).to_not have_content(t('forms.webauthn_platform_setup.info_text'))
      end

      context 'when another method must be set up afterwards' do
        before do
          assign(:need_to_set_up_additional_mfa, true)
        end

        it 'renders the info alert' do
          render

          expect(rendered).to have_selector(
            '.auth--form-page .usa-alert--info',
            text: t('forms.webauthn_platform_setup.info_text'),
          )
        end
      end

      context 'with the passkey upsell auto prompt' do
        let(:passkey_upsell) { true }

        before do
          assign(:passkey_upsell, true)
          assign(:auto_trigger, true)
        end

        it 'keeps the upsell heading, intro and button' do
          render

          expect(rendered).to have_selector('h1', text: t('webauthn_platform_setup.upsell'))
          expect(rendered).to have_content(t('webauthn_platform_setup.instructions'))
          expect(rendered).to have_link(t('webauthn_platform_setup.phishing_resistant'))
          expect(rendered).to have_button(t('webauthn_platform_recommended.cta'))
        end

        it 'keeps the auto-trigger hook and upsell params on the form' do
          render

          expect(rendered).to have_selector(
            "form#webauthn-form[data-auto-trigger='true'][action='#{webauthn_setup_path(
              platform: true, auto_trigger: true, passkey_upsell: true,
            )}']",
          )
        end
      end
    end

    context 'non-platform webauthn' do
      let(:platform_authenticator) { false }

      it 'renders the security key heading and learn-more link' do
        render

        expect(rendered).to have_selector('h1', text: t('headings.webauthn_setup.new'))
        expect(rendered).to have_content(t('forms.webauthn_setup.intro', app_name: APP_NAME))
        expect(rendered).to have_link(
          t('forms.webauthn_setup.learn_more'),
          href: help_center_redirect_path(
            category: 'get-started',
            article: 'authentication-methods',
            article_anchor: 'security-key',
            flow: :two_factor_authentication,
            step: :security_key_setup,
          ),
        )
      end

      it 'renders the three numbered steps' do
        render

        expect(rendered).to have_selector('ol li', text: t('forms.webauthn_setup.step_1'))
        expect(rendered).to have_selector('ol li', text: t('forms.webauthn_setup.step_2'))
        expect(rendered).to have_selector('ol li', text: t('forms.webauthn_setup.step_3'))
        expect(rendered).to have_content(t('forms.webauthn_setup.step_3a'))
      end

      it 'renders the required nickname field' do
        render

        expect(rendered).to have_field(
          t('forms.webauthn_setup.nickname'),
          id: 'nickname',
          type: 'text',
        )
        expect(rendered).to have_selector(
          "input#nickname[name='name'][required][maxlength='20']" \
          "[aria-describedby~='webauthn-step-1-hint']",
        )
      end

      it 'posts without the platform param' do
        render

        expect(rendered).to have_selector("form#webauthn-form[action='#{webauthn_setup_path}']")
        expect(rendered).to have_field('platform_authenticator', type: :hidden, with: 'false')
      end

      it 'renders the set up security key button' do
        render

        expect(rendered).to have_button(t('forms.webauthn_setup.set_up'))
      end

      it 'displays the security key image' do
        render

        expect(rendered).to have_css('.card svg.width-full:not(.security-key--mobile)')
      end

      context 'when on a mobile device' do
        before do
          allow(view).to receive(:mobile?).and_return(true)
        end

        it 'displays the mobile security key image' do
          render

          expect(rendered).to have_css('svg.security-key--mobile')
        end
      end
    end
  end
end
