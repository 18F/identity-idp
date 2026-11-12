require 'rails_helper'

RSpec.describe 'users/two_factor_authentication_setup/index.html.erb' do
  include Devise::Test::ControllerHelpers
  include IdvHelper

  let(:user) { build(:user) }
  let(:user_agent) { '' }
  let(:show_skip_additional_mfa_link) { true }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  let(:in_account_creation_flow) { false }
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
      piv_cac_required:,
    )
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
    allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.two_factor_setup'))

    render
  end

  context 'in the default layout' do
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

    it 'renders the platform authenticator hidden input with no preset value' do
      field = Nokogiri::HTML(rendered).at_css('input#platform_authenticator_available')
      expect(field['value'].to_s).to eq('')
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

      it 'renders the phishing-resistant intro and important alert icon' do
        expect(rendered).to have_content(
          t('two_factor_authentication.two_factor_aal3_choice_intro'),
        )
        expect(rendered).to have_css(
          "img[alt='#{t('two_factor_authentication.important_alert_icon')}']",
        )
      end
    end

    context 'when PIV/CAC is required' do
      let(:user) { create(:user, :fully_registered, :with_phone) }
      let(:piv_cac_required) { true }

      it 'renders the PIV/CAC step-up heading, intro and important alert icon' do
        expect(rendered).to have_css(
          'h1',
          text: t('two_factor_authentication.two_factor_hspd12_choice'),
        )
        expect(rendered).to have_content(
          t('two_factor_authentication.two_factor_hspd12_choice_intro'),
        )
        expect(rendered).to have_css(
          "img[alt='#{t('two_factor_authentication.important_alert_icon')}']",
        )
      end

      it 'offers only PIV/CAC' do
        expect(rendered).to have_field('two_factor_options_form[selection][]', with: :piv_cac)
        expect(rendered).not_to have_field('two_factor_options_form[selection][]', with: :webauthn)
        expect(rendered).not_to have_field('two_factor_options_form[selection][]', with: :phone)
      end

      it 'shows a cancel link back to the partner' do
        expect(rendered).to have_link(t('links.cancel'), href: return_to_sp_cancel_path)
      end
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).not_to have_css('.auth--form-page')
    end

    it 'does not render the NDS mfa options card list' do
      expect(rendered).not_to have_css('.mfa-options')
    end
  end

  context 'in the NDS layout' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'renders the FormPageComponent card with the NDS heading' do
      expect(rendered).to have_css('.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.mfa_setup.heading'))
    end

    it 'renders the mfa options card list container' do
      expect(rendered).to have_css('.mfa-options[data-mfa-options]')
    end

    it 'renders each option as a card submit control with a title' do
      expect(rendered).to have_css('.mfa-options .card--mfa[type="submit"]')
      expect(rendered).to have_css(
        '.mfa-options .card--mfa .card__title',
        text: t('nds.mfa_setup.options.phone'),
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

    it 'renders the platform authenticator hidden field with no preset value' do
      field = Nokogiri::HTML(rendered).at_css('input#platform_authenticator_available')
      expect(field['value'].to_s).to eq('')
    end

    it 'does not render a cancel account creation link for a new user' do
      expect(rendered).to have_no_link(t('links.cancel_account_creation'))
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

    context 'when a method is already configured' do
      let(:user) { build(:user, :with_phone) }

      it 'renders the second-method heading and intro' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.mfa_setup.heading_second'),
        )
        expect(rendered).to have_content(t('nds.mfa_setup.intro_second'))
      end

      it 'renders skip as a secondary button in the actions region, not a link' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button.usa-button--secondary',
          text: t('mfa.skip'),
        )
        expect(rendered).to have_no_link(t('links.cancel_account_creation'))
      end
    end

    it 'does not render the step-up icon, intro or recommended tags' do
      expect(rendered).not_to have_css('.nds-status-icon')
      expect(rendered).not_to have_content(t('mfa.recommendation'))
      expect(rendered).not_to have_css(
        '.card__badge',
        text: t('two_factor_authentication.recommended'),
      )
    end

    context 'when phishing-resistant MFA is required at sign-in' do
      let(:user) { create(:user, :fully_registered, :with_phone) }
      let(:phishing_resistant_required) { true }
      let(:enabled_mfa_methods_count) { 1 }

      it 'renders the step-up heading with the status icon' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.mfa_setup.heading_step_up'),
        )
        expect(rendered).to have_css(
          ".auth__header--with-media .nds-status-icon " \
          "svg[aria-label='#{t('two_factor_authentication.important_alert_icon')}']",
        )
      end

      it 'renders the phishing-resistant intro and recommendation below a divider' do
        expect(rendered).not_to have_css('.auth__intro-description')
        expect(rendered).to have_css('.auth__form-page-body hr.divider')
        expect(rendered).to have_css(
          '.auth__form-page-body .copy p',
          text: t('two_factor_authentication.two_factor_aal3_choice_intro'),
        )
        expect(rendered).to have_css('.auth__form-page-body .copy p', text: t('mfa.recommendation'))
      end

      it 'offers only phishing-resistant methods, all expanded' do
        values = Nokogiri::HTML(rendered).css('.mfa-options .card--mfa').map { |card| card['value'] }
        expect(values).to eq(%w[webauthn_platform webauthn piv_cac])
        expect(rendered).not_to have_css('.mfa-options__item--extra')
        expect(rendered).not_to have_css('.mfa-options__more')
      end

      it 'renders cancel back to the partner in the actions region' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{return_to_sp_cancel_path}']",
          text: t('links.cancel'),
        )
        expect(rendered).to have_no_link(t('mfa.skip'))
      end

      it 'does not render the account creation progress' do
        rendered
        expect(view.content_for(:nds_header_progress)).to be_blank
      end

      context 'with a .gov or .mil email' do
        let(:user) { create(:user, :fully_registered, :with_phone, email: 'example@mail.mil') }

        it 'lists PIV/CAC first with a Recommended tag' do
          cards = Nokogiri::HTML(rendered).css('.mfa-options .card--mfa')
          expect(cards.first['value']).to eq('piv_cac')
          expect(cards.first.at_css('.card__badge').text).to eq(
            t('two_factor_authentication.recommended'),
          )
        end
      end
    end

    context 'when phishing-resistant MFA is required during account creation' do
      let(:phishing_resistant_required) { true }
      let(:in_account_creation_flow) { true }

      it 'keeps the setup heading without the status icon' do
        expect(rendered).to have_css('.auth--form-page h1', text: t('nds.mfa_setup.heading'))
        expect(rendered).not_to have_css('.nds-status-icon')
      end

      it 'renders the phishing-resistant intro below a divider' do
        expect(rendered).to have_css('.auth__form-page-body hr.divider')
        expect(rendered).to have_css(
          '.auth__form-page-body .copy p',
          text: t('two_factor_authentication.two_factor_aal3_choice_intro'),
        )
        expect(rendered).not_to have_content(t('nds.mfa_setup.intro'))
      end

      it 'renders cancel back to the partner in the actions region' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{return_to_sp_cancel_path}']",
          text: t('links.cancel'),
        )
      end

      it 'keeps the account creation progress at Security 1 / 2' do
        rendered
        expect(view.content_for(:nds_header_progress)).to have_css(
          '.progress__step[aria-current="step"] .progress__step-counter',
          text: '1 / 2',
        )
      end
    end

    context 'when PIV/CAC is required' do
      let(:user) { create(:user, :fully_registered, :with_phone) }
      let(:piv_cac_required) { true }

      it 'renders the step-up heading with the status icon' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.mfa_setup.heading_step_up'),
        )
        expect(rendered).to have_css('.auth__header--with-media .nds-status-icon svg')
      end

      it 'renders the PIV/CAC intro and recommendation below a divider' do
        expect(rendered).to have_css('.auth__form-page-body hr.divider')
        expect(rendered).to have_css(
          '.auth__form-page-body .copy p',
          text: t('two_factor_authentication.two_factor_hspd12_choice_intro'),
        )
        expect(rendered).to have_css('.auth__form-page-body .copy p', text: t('mfa.recommendation'))
      end

      it 'offers only PIV/CAC' do
        values = Nokogiri::HTML(rendered).css('.mfa-options .card--mfa').map { |card| card['value'] }
        expect(values).to eq(%w[piv_cac])
      end

      it 'renders cancel back to the partner in the actions region' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{return_to_sp_cancel_path}']",
          text: t('links.cancel'),
        )
      end
    end
  end
end
