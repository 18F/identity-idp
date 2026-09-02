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

  let(:enabled_mfa_methods_count) { 0 }

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
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
  end

  it 'has link to cancel account creation' do
    expect(rendered).to have_css('.page-footer')
    expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
  end

  it 'does not list currently configured mfa methods' do
    expect(rendered).not_to have_content(t('headings.account.two_factor'))
  end

  it 'renders hidden input for platform authenticator support' do
    expect(rendered).to have_css('input#platform_authenticator_available', visible: false)
  end

  context 'with configured mfa methods' do
    let(:user) { build(:user, :with_phone) }

    it 'lists currently configured mfa methods' do
      expect(rendered).to have_content(t('headings.account.two_factor'))
    end

    it 'has link to skip additional mfa setup' do
      expect(rendered).to have_css('.page-footer')
      expect(rendered).to have_link(t('mfa.skip'), href: after_mfa_setup_path)
    end

    context 'with skip link hidden' do
      let(:show_skip_additional_mfa_link) { false }

      it 'does not have footer link' do
        expect(rendered).not_to have_css('.page-footer')
        expect(rendered).not_to have_link(t('links.cancel_account_creation'))
        expect(rendered).not_to have_link(t('mfa.skip'))
      end
    end
  end

  context 'all phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:all_vendor_outage?)
        .with(OutageStatus::PHONE_VENDORS).and_return(true)
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
      expect(rendered).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(rendered).to have_content(
        t('two_factor_authentication.two_factor_choice_options.phone'),
      )
    end

    it 'shows a cancel link that aborts the login' do
      expect(rendered).not_to have_link(t('mfa.skip'))
      expect(rendered).to have_link(t('links.cancel'))
    end
  end

  context 'legacy (non-nds) bucket' do
    it 'does not render the NDS form-page card' do
      expect(rendered).not_to have_css('.auth--form-page')
    end

    it 'does not render the NDS mfa options card list' do
      expect(rendered).not_to have_css('.mfa-options')
    end
  end

  context 'nds bucket' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'renders the FormPageComponent card with the presenter heading' do
      expect(rendered).to have_css('.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: @presenter.heading)
    end

    it 'renders the mfa options card list container' do
      expect(rendered).to have_css('.mfa-options[data-mfa-options]')
    end

    it 'renders each option as a card submit control with a title' do
      expect(rendered).to have_css('.mfa-options .card--mfa[type="submit"]')
      expect(rendered).to have_css(
        '.mfa-options .card--mfa .card__title',
        text: t('two_factor_authentication.two_factor_choice_options.phone'),
      )
    end

    it 'submits the selected option via the card control name' do
      expect(rendered).to have_css(
        ".mfa-options .card--mfa[name='two_factor_options_form[selection][]']",
      )
    end

    it 'renders a chevron on enabled options' do
      expect(rendered).to have_css('.mfa-options .card--mfa .card__trailing .usa-icon')
    end

    it 'marks options beyond the first two as extra' do
      expect(rendered).to have_css('.mfa-options .mfa-options__item--extra')
    end

    it 'renders the more options button when there are more than two options' do
      expect(rendered).to have_css('.mfa-options__more', text: t('mfa.more_options'))
    end

    it 'posts the form with :patch to authentication_methods_setup_path' do
      expect(rendered).to have_css(
        "form[action='#{authentication_methods_setup_path}']" \
        " input[name='_method'][value='patch']",
        visible: :all,
      )
    end

    it 'renders the platform authenticator hidden field' do
      expect(rendered).to have_css('input#platform_authenticator_available', visible: false)
    end

    it 'renders the cancel account creation footer link for a new user' do
      expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
    end

    context 'first MFA (no methods configured yet)' do
      let(:enabled_mfa_methods_count) { 0 }

      it 'sets the header progress to Security substep 1 / 2' do
        rendered
        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css('nds-progress.progress')
        expect(progress).to have_css(
          '.progress__step[aria-current="step"]',
          text: t('step_indicator.flows.account_creation.security'),
        )
        expect(progress).to have_css(
          '.progress__step[aria-current="step"] .progress__step-counter',
          text: '1 / 2',
        )
      end
    end

    context 'second MFA (one method already configured)' do
      let(:enabled_mfa_methods_count) { 1 }

      it 'sets the header progress to Security substep 2 / 2' do
        rendered
        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css(
          '.progress__step[aria-current="step"] .progress__step-counter',
          text: '2 / 2',
        )
      end
    end
  end
end
