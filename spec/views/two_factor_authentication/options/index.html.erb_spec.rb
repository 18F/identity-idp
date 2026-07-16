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
    expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_out_path)
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
      expect(rendered).to have_selector('.ads-alert.ads-alert--error')
    end

    it 'disables problematic vendor option' do
      expect(rendered).to have_css(
        "button[name='two_factor_options_form[selection]'][value='voice']:not([disabled])",
      )
      expect(rendered).to have_css(
        "button[name='two_factor_options_form[selection]'][value='sms'][disabled]",
      )
    end
  end

  context 'when adding piv cac after 2fa' do
    let(:add_piv_cac_after_2fa) { true }

    it 'displays info text for adding piv cac after 2fa' do
      expect(rendered).to have_selector(
        '.ads-alert.ads-alert--neutral',
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
        '.ads-alert.ads-alert--warning',
        text: t('two_factor_authentication.aal2_request.phishing_resistant', sp_name: APP_NAME),
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
        '.ads-alert.ads-alert--warning',
        text: t('two_factor_authentication.aal2_request.piv_cac_only', sp_name: APP_NAME),
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
end
