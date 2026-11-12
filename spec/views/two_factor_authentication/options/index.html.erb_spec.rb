require 'rails_helper'

RSpec.describe 'two_factor_authentication/options/index.html.erb' do
  let(:user) { User.new }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  let(:reauthentication_context) { false }
  let(:add_piv_cac_after_2fa) { false }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:current_user).and_return(user)

    @presenter = TwoFactorLoginOptionsPresenter.new(
      user:,
      view:,
      reauthentication_context:,
      service_provider: nil,
      phishing_resistant_required:,
      piv_cac_required:,
      add_piv_cac_after_2fa:,
    )
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(
      t('two_factor_authentication.login_options_title'),
    )

    rendered
  end

  context 'in the default layout' do
    it 'has a localized heading' do
      expect(rendered).to have_content \
        t('two_factor_authentication.login_options_title')
    end

    it 'has a localized intro text' do
      expect(rendered).to have_content \
        t('two_factor_authentication.login_intro')
    end

    it 'has a cancel link' do
      expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
    end

    it 'does not display info text for adding piv cac after 2fa' do
      expect(rendered).not_to have_content(
        t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'),
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'phone vendor outage' do
      let(:user) { User.new }
      before do
        create(:phone_configuration, user: user, phone: '(202) 555-1111')
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it 'renders alert banner' do
        expect(rendered).to have_selector('.usa-alert.usa-alert--error')
      end

      it 'disables problematic vendor option' do
        expect(rendered).to have_checked_field(
          'two_factor_options_form[selection]',
          with: :voice,
          disabled: false,
        )
        expect(rendered).to have_field(
          'two_factor_options_form[selection]',
          with: :sms,
          disabled: true,
        )
      end
    end

    context 'when adding piv cac after 2fa' do
      let(:add_piv_cac_after_2fa) { true }

      it 'displays info text for adding piv cac after 2fa' do
        expect(rendered).to have_selector(
          '.usa-alert.usa-alert--info',
          text: t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'),
        )
      end
    end

    context 'with phishing resistant required' do
      let(:user) do
        create(
          :user,
          :fully_registered,
          :with_webauthn,
          :with_webauthn_platform,
          :with_phone,
          :with_piv_or_cac,
          :with_personal_key,
          :with_backup_code,
          :with_authentication_app,
        )
      end
      let(:phishing_resistant_required) { true }

      it 'displays warning text' do
        expect(rendered).to have_selector(
          '.usa-alert.usa-alert--warning',
          text: strip_tags(
            t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name: APP_NAME),
          ),
        )
      end
    end

    context 'with piv cac required' do
      let(:user) do
        create(
          :user,
          :fully_registered,
          :with_webauthn,
          :with_webauthn_platform,
          :with_phone,
          :with_piv_or_cac,
          :with_personal_key,
          :with_backup_code,
          :with_authentication_app,
        )
      end
      let(:piv_cac_required) { true }

      it 'displays warning text' do
        expect(rendered).to have_selector(
          '.usa-alert.usa-alert--warning',
          text: strip_tags(
            t('two_factor_authentication.aal2_request.piv_cac_only_html', sp_name: APP_NAME),
          ),
        )
      end
    end

    context 'with context reauthentication' do
      let(:reauthentication_context) { true }

      it 'has a localized heading' do
        expect(rendered).to have_content \
          t('two_factor_authentication.login_options_reauthentication_title')
      end

      it 'has a localized intro text' do
        expect(rendered).to have_content \
          t('two_factor_authentication.login_intro_reauthentication')
      end
    end

    describe 'account recovery entry point' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'only offers the legacy delete-your-account link by default' do
        expect(rendered).to have_link(t('two_factor_authentication.account_reset.link'))
        expect(rendered).to_not have_link(
          t('two_factor_authentication.account_recovery.recover_link'),
        )
      end

      context 'when the user is eligible for account recovery' do
        let(:user) { create(:user, :fully_registered) }

        before do
          allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
        end

        it 'offers recovery without linking to the legacy deletion flow' do
          expect(rendered).to have_link(
            t('two_factor_authentication.account_recovery.recover_link'),
            href: account_recovery_start_path(locale: LinkLocaleResolver.locale),
          )
          expect(rendered).not_to have_link(
            href: account_reset_recovery_options_path(locale: LinkLocaleResolver.locale),
          )
        end

        it 'does not render the legacy single-option text' do
          expect(rendered).to_not have_content(
            strip_tags(t('two_factor_authentication.account_reset.text_html')),
          )
        end

        context 'with an active recovery request' do
          before { create(:account_recovery_request, :waiting, user: user) }

          it 'offers neither legacy deletion nor a second recovery request' do
            expect(rendered).not_to have_link(href: account_recovery_start_path)
            expect(rendered).not_to have_link(t('two_factor_authentication.account_reset.link'))
            expect(rendered).not_to have_link(
              t('two_factor_authentication.account_recovery.recover_link'),
            )
          end
        end

        context 'with an identity-proofed user' do
          let(:user) { create(:user, :proofed) }

          it 'retains legacy recovery for ineligible users' do
            expect(rendered).to have_link(t('two_factor_authentication.account_reset.link'))
            expect(rendered).not_to have_link(
              t('two_factor_authentication.account_recovery.recover_link'),
            )
          end
        end
      end
    end
  end

  context 'in the NDS layout' do
    let(:selection_field) { 'two_factor_options_form[selection]' }
    let(:option_values) do
      Nokogiri::HTML(rendered)
        .css(".auth__form-page-body button.card--mfa[name='#{selection_field}']")
        .map { |button| button[:value] }
    end

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    def with_platform_authenticator(user)
      create(:webauthn_configuration, :platform_authenticator, user:)
      user.webauthn_configurations.reset
      user
    end

    it 'renders the form-page card with the select-method heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.login_options_title'),
      )
      expect(rendered).to_not have_content(t('two_factor_authentication.login_intro'))
    end

    it 'posts the selection to the options path without radios or a Continue button' do
      expect(rendered).to have_css(
        ".auth__form-page-body form[action='#{login_two_factor_options_path}'][method='post']",
      )
      expect(rendered).to have_css(
        ".mfa-options[role='group']" \
          "[aria-label='#{t('two_factor_authentication.login_options_title')}']",
      )
      expect(rendered).to_not have_field(selection_field, type: :radio)
      expect(rendered).to_not have_button(t('forms.buttons.continue'))
    end

    context 'with an account still being created' do
      it 'provides a cancel button to the sign-up cancel page' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_up_cancel_path}']",
          text: t('links.cancel_account_creation'),
        )
      end
    end

    context 'with a user who has every method' do
      let(:user) do
        with_platform_authenticator(
          create(
            :user,
            :fully_registered,
            :with_webauthn,
            :with_phone,
            :with_piv_or_cac,
            :with_personal_key,
            :with_backup_code,
            :with_authentication_app,
          ),
        )
      end

      it 'renders one submit card per method in the design order' do
        expect(option_values).to eq(
          %w[webauthn_platform sms voice auth_app webauthn backup_code piv_cac personal_key],
        )
        expect(rendered).to have_css('button.card--mfa[type=submit]', count: 8)
      end

      it 'labels each card with the method name and description' do
        expect(rendered).to have_css(
          "button[value='webauthn_platform'] .card__title",
          text: t('nds.mfa_setup.options.webauthn_platform'),
        )
        expect(rendered).to have_css(
          "button[value='webauthn_platform'] .card__description",
          text: t('nds.mfa_options.webauthn_platform_info'),
        )
        expect(rendered).to have_css(
          "button[value='sms'] .card__title",
          text: t('two_factor_authentication.login_options.sms'),
        )
        expect(rendered).to have_css(
          "button[value='sms'] .card__description strong",
          text: user.phone_configurations.first.masked_phone,
        )
        expect(rendered).to have_css(
          "button[value='voice'] .card__title",
          text: t('two_factor_authentication.login_options.voice'),
        )
        expect(rendered).to have_css(
          "button[value='auth_app'] .card__description",
          text: t('two_factor_authentication.login_options.auth_app_info'),
        )
        expect(rendered).to have_css(
          "button[value='webauthn'] .card__title",
          text: t('two_factor_authentication.login_options.webauthn'),
        )
        expect(rendered).to have_css(
          "button[value='backup_code'] .card__title",
          text: t('two_factor_authentication.login_options.backup_code'),
        )
        expect(rendered).to have_css(
          "button[value='piv_cac'] .card__description",
          text: t('nds.mfa_setup.options.piv_cac_info'),
        )
        expect(rendered).to have_css(
          "button[value='personal_key'] .card__title",
          text: t('forms.two_factor.personal_key'),
        )
      end

      it 'wraps security key options in the webauthn support check' do
        expect(rendered).to have_css("lg-webauthn-input button[value='webauthn_platform']")
        expect(rendered).to have_css("lg-webauthn-input button[value='webauthn']")
      end

      it 'provides a cancel button that signs the user out' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{sign_out_path}']",
          text: t('links.cancel'),
        )
      end
    end

    context 'with more than one phone' do
      let(:user) { create(:user, :fully_registered) }
      let!(:second_phone) do
        create(:phone_configuration, user:, phone: '+1 202-555-3434', made_default_at: nil)
      end

      it 'submits the configuration id with each phone selection' do
        first_phone = user.phone_configurations.reject { |phone| phone == second_phone }.first

        expect(option_values).to include(
          "sms_#{first_phone.id}",
          "voice_#{first_phone.id}",
          "sms_#{second_phone.id}",
          "voice_#{second_phone.id}",
        )
      end
    end

    context 'phone vendor outage' do
      before do
        create(:phone_configuration, user: user, phone: '(202) 555-1111')
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it 'renders the outage alert and disables the affected card' do
        expect(rendered).to have_css('.auth--form-page .usa-alert.usa-alert--error')
        expect(rendered).to have_css("button.card--mfa[value='sms'][disabled]")
        expect(rendered).to have_css("button.card--mfa[value='voice']:not([disabled])")
      end
    end

    context 'when adding piv cac after 2fa' do
      let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }
      let(:add_piv_cac_after_2fa) { true }

      before do
        allow(view).to receive(:user_session).and_return({ add_piv_cac_after_2fa: true })
      end

      it 'renders the info alert and disables the PIV/CAC card' do
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert.usa-alert--info',
          text: t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'),
        )
        expect(rendered).to have_css("button.card--mfa[value='piv_cac'][disabled]")
      end
    end

    context 'with phishing resistant required' do
      let(:user) do
        with_platform_authenticator(
          create(
            :user,
            :fully_registered,
            :with_webauthn,
            :with_phone,
            :with_piv_or_cac,
            :with_authentication_app,
          ),
        )
      end
      let(:phishing_resistant_required) { true }

      it 'renders the warning and only phishing-resistant cards' do
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert.usa-alert--warning',
          text: strip_tags(
            t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name: APP_NAME),
          ),
        )
        expect(option_values).to eq(%w[webauthn_platform webauthn piv_cac])
      end
    end

    context 'with piv cac required' do
      let(:user) do
        create(:user, :fully_registered, :with_webauthn, :with_phone, :with_piv_or_cac)
      end
      let(:piv_cac_required) { true }

      it 'renders the warning and only the PIV/CAC card' do
        expect(rendered).to have_css(
          '.auth--form-page .usa-alert.usa-alert--warning',
          text: strip_tags(
            t('two_factor_authentication.aal2_request.piv_cac_only_html', sp_name: APP_NAME),
          ),
        )
        expect(option_values).to eq(%w[piv_cac])
      end
    end

    context 'with context reauthentication' do
      let(:user) { create(:user, :fully_registered) }
      let(:reauthentication_context) { true }

      it 'renders the reauthentication heading and intro and cancels back to the account' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('two_factor_authentication.login_options_reauthentication_title'),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: t('two_factor_authentication.login_intro_reauthentication'),
        )
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('links.cancel'),
        )
      end
    end

    describe 'account recovery entry point' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'offers the legacy delete-your-account link below the cards' do
        expect(rendered).to have_css(
          '.auth__actions .copy a',
          text: t('two_factor_authentication.account_reset.link'),
        )
      end

      context 'with a granted account deletion request' do
        before do
          allow(@presenter).to receive(:account_reset_token_valid?).and_return(true)
          allow(@presenter).to receive(:account_reset_token).and_return('foo')
        end

        it 'offers to cancel the pending deletion' do
          expect(rendered).to have_link(
            t('two_factor_authentication.account_reset.cancel_link'),
            href: account_reset_cancel_url(token: 'foo'),
          )
        end
      end

      context 'when the user is eligible for account recovery' do
        let(:user) { create(:user, :fully_registered) }

        before do
          allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
        end

        it 'offers recovery instead of the legacy deletion flow' do
          expect(rendered).to have_link(
            t('two_factor_authentication.account_recovery.recover_link'),
            href: account_recovery_start_path(locale: LinkLocaleResolver.locale),
          )
          expect(rendered).not_to have_link(t('two_factor_authentication.account_reset.link'))
        end

        context 'with an active recovery request' do
          before { create(:account_recovery_request, :waiting, user: user) }

          it 'offers neither legacy deletion nor a second recovery request' do
            expect(rendered).not_to have_css('.auth__actions .copy')
            expect(rendered).not_to have_link(t('two_factor_authentication.account_reset.link'))
            expect(rendered).not_to have_link(
              t('two_factor_authentication.account_recovery.recover_link'),
            )
          end
        end
      end
    end
  end
end
