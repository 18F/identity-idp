require 'rails_helper'

RSpec.describe 'users/two_factor_authentication_setup/index.html.erb' do
  include Devise::Test::ControllerHelpers
  include IdvHelper

  let(:user) { build(:user) }
  let(:user_agent) { '' }
  let(:show_skip_additional_mfa_link) { true }
  let(:phishing_resistant_required) { false }
  let(:after_mfa_setup_path) { account_path }
  subject(:rendered) { render }

  before do
    @presenter = TwoFactorOptionsPresenter.new(
      user_agent:,
      user:,
      show_skip_additional_mfa_link:,
      after_mfa_setup_path:,
      return_to_sp_cancel_path:,
      phishing_resistant_required:,
    )
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
  end

  it 'does not render continue or cancel actions' do
    expect(rendered).not_to have_css('.ads-auth__actions')
    expect(rendered).not_to have_button(t('forms.buttons.continue'))
    expect(rendered).not_to have_link(t('links.cancel_account_creation'))
  end

  it 'renders hidden input for platform authenticator support' do
    expect(rendered).to have_css('input#platform_authenticator_available', visible: false)
  end

  it 'renders option cards that submit a selection' do
    expect(rendered).to have_button(
      type: 'submit',
      id: 'two_factor_options_form_selection_phone',
    )
    expect(rendered).to have_css(
      'button[name="two_factor_options_form[selection][]"][value="phone"]',
    )
  end

  context 'with configured mfa methods' do
    let(:user) { build(:user, :with_phone) }

    it 'does not list currently configured mfa methods' do
      expect(rendered).not_to have_content(t('headings.account.two_factor'))
    end

    it 'does not render skip link' do
      expect(rendered).not_to have_link(t('mfa.skip'))
    end
  end

  context 'all phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:all_vendor_outage?)
        .with(OutageStatus::PHONE_VENDORS).and_return(true)
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.ads-alert.ads-alert--error')
    end

    it 'disables phone option' do
      expect(rendered).to have_css(
        '#two_factor_options_form_selection_phone[disabled]',
      )
    end
  end

  context 'single phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'does not render alert banner' do
      expect(rendered).to_not have_selector('.usa-alert.usa-alert--error')
    end

    it 'does not disable phone option' do
      expect(rendered).to have_css('#two_factor_options_form_selection_phone:not([disabled])')
    end
  end

  context 'unphishable requires additional authentication to be added' do
    let(:user) { create(:user, :fully_registered, :with_phone) }
    let(:phishing_resistant_required) { true }

    it 'lists current selected mfa methods' do
      expect(rendered).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(rendered).to have_content(
        t('two_factor_authentication.two_factor_choice_options.phone'),
      )
    end

    it 'does not show cancel or skip links' do
      expect(rendered).not_to have_link(t('mfa.skip'))
      expect(rendered).not_to have_link(t('links.cancel'))
    end
  end
end
