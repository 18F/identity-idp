require 'rails_helper'

RSpec.describe 'users/two_factor_authentication_setup/index.html.erb' do
  include Devise::Test::ControllerHelpers
  include IdvHelper

  let(:user) { build(:user) }
  let(:user_agent) { '' }
  let(:show_skip_additional_mfa_link) { true }
  let(:phishing_resistant_required) { false }
  let(:after_mfa_setup_path) { account_path }
  let(:return_to_sp_cancel_path) { '/redirect/return_to_sp/cancel' }
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

  it 'has link to cancel account creation' do
    render

    expect(rendered).to have_css('.page-footer')
    expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
  end

  it 'does not list currently configured mfa methods' do
    render

    expect(rendered).not_to have_content(t('headings.account.two_factor'))
  end

  context 'with configured mfa methods' do
    let(:user) { build(:user, :with_phone) }

    it 'lists currently configured mfa methods' do
      render

      expect(rendered).to have_content(t('headings.account.two_factor'))
    end

    it 'has link to skip additional mfa setup' do
      render

      expect(rendered).to have_css('.page-footer')
      expect(rendered).to have_link(t('mfa.skip'), href: after_mfa_setup_path)
    end

    context 'with skip link hidden' do
      let(:show_skip_additional_mfa_link) { false }

      it 'does not have footer link' do
        render

        expect(rendered).not_to have_css('.page-footer')
        expect(rendered).not_to have_link(t('links.cancel_account_creation'))
        expect(rendered).not_to have_link(t('mfa.skip'))
      end
    end
  end

  context 'all phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:all_vendor_outage?).
        with(OutageStatus::PHONE_VENDORS).and_return(true)
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end

    it 'disables phone option' do
      expect(rendered).to have_field(
        'two_factor_options_form[selection][]',
        with: :phone,
        disabled: true,
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
      expect(rendered).to have_field(
        'two_factor_options_form[selection][]',
        with: :phone,
        disabled: false,
      )
    end
  end

  context 'unphishable requires additional authentication to be added' do
    let(:user) { create(:user, :fully_registered, :with_phone) }
    let(:phishing_resistant_required) { true }

    it 'lists current selected mfa methods' do
      render
      expect(rendered).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(rendered).to have_content(
        t('two_factor_authentication.two_factor_choice_options.phone'),
      )
    end

    it 'shows a cancel link that aborts the login' do
      render
      expect(rendered).not_to have_link(t('mfa.skip'))
      expect(rendered).to have_link(t('links.cancel'))
    end
  end
end
