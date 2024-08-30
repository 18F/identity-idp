require 'rails_helper'

RSpec.describe 'users/webauthn_setup/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }

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
    )
  end

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
    allow(view).to receive(:mobile?).and_return(false)
    assign(:platform_authenticator, platform_authenticator)
    assign(:user_session, user_session)
    assign(:presenter, presenter)
  end

  context 'webauthn platform' do
    let(:platform_authenticator) { true }

    it 'has a localized title' do
      expect(view).to receive(:title=).with(presenter.page_title)

      render
    end

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
