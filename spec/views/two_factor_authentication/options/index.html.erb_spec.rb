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
    allow(view).to receive(:current_user).and_return(User.new)

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
end
