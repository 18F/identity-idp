require 'rails_helper'

RSpec.describe 'two_factor_authentication/options/index.html.erb' do
  let(:user) { User.new }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  let(:reauthentication_context) { false }
  let(:add_piv_cac_after_2fa) { false }

  subject(:rendered) { render }

  before do
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

        it 'links to recovery status without offering legacy deletion or a second recovery' do
          expect(rendered).to have_link(
            t('two_factor_authentication.account_recovery.pending_link'),
            href: account_recovery_pending_status_path(locale: LinkLocaleResolver.locale),
          )
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
