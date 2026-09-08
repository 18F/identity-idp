require 'rails_helper'

RSpec.describe 'users/phone_setup/index.html.erb' do
  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:nds_layout?).and_return(false)

    @new_phone_form = NewPhoneForm.new(user:)

    @presenter = SetupPresenter.new(
      current_user: user,
      user_fully_authenticated: false,
      user_opted_remember_device_cookie: true,
      remember_device_default: true,
    )
  end

  it 'sets form autocomplete to off' do
    expect(render).to have_xpath("//form[@autocomplete='off']")
  end

  it 'renders a link to choose a different option' do
    expect(render).to have_link(
      t('two_factor_authentication.choose_another_option'),
      href: authentication_methods_setup_path,
    )
  end

  context 'voip numbers' do
    it 'tells users to not use VOIP numbers' do
      expect(render).to have_content(
        t('two_factor_authentication.two_factor_choice_options.phone_info_no_voip'),
      )
    end
  end

  context 'recaptcha enabled' do
    before do
      allow(FeatureManagement).to receive(:phone_recaptcha_enabled?).and_return(true)
    end

    it 'contains link to Google policy page' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.recaptcha.google_policy_link'),
        href: GooglePolicySite.privacy_url,
      )
    end

    it 'contains link to Google terms page' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.recaptcha.google_tos_link'),
        href: GooglePolicySite.terms_url,
      )
    end

    it 'contains link to Terms of Use page' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.recaptcha.login_tos_link'),
        href: MarketingSite.rules_of_use_url,
      )
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'renders alert banner' do
      expect(render).to have_selector('.usa-alert.usa-alert--error')
    end
  end

  context 'nds bucket' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
      allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
      allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
      render
    end

    let(:enabled_mfa_methods_count) { 0 }
    let(:in_account_creation_flow) { true }

    it 'renders the FormPageComponent card with the NDS heading' do
      expect(rendered).to have_css('.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.phone_setup.heading'))
    end

    it 'renders the phone input and delivery preference radios' do
      expect(rendered).to have_css('.usa-phone-input')
      expect(rendered).to have_css(
        'details.usa-phone-input__country .usa-phone-input__country-toggle',
      )
      expect(rendered).to have_css(
        ".usa-phone-input__country-radio[name='new_phone_form[international_code]'][value='US']",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".usa-phone-input input.usa-phone-input__input[type='tel'][name='new_phone_form[phone]']",
      )
      expect(rendered).to have_css('.radio-group')
      expect(rendered).to have_css(
        ".radio-group .radio__input[name='new_phone_form[otp_delivery_preference]'][value='sms']",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".radio-group .radio__input[name='new_phone_form[otp_delivery_preference]'][value='voice']",
        visible: :all,
      )
    end

    it 'visually hides the delivery preference legend for screen readers' do
      expect(rendered).to have_css(
        'legend.usa-sr-only',
        text: t('two_factor_authentication.otp_delivery_preference.title'),
      )
    end

    it 'posts the form to phone_setup_path with the send code button' do
      expect(rendered).to have_css("form[action='#{phone_setup_path}']")
      expect(rendered).to have_button(t('forms.buttons.send_one_time_code'))
    end

    it 'renders a link to choose another method' do
      expect(rendered).to have_link(
        t('nds.mfa.choose_another_method'),
        href: authentication_methods_setup_path,
      )
    end

    context 'during account creation' do
      let(:in_account_creation_flow) { true }

      it 'sets the header progress to Security substep 1 / 2' do
        rendered
        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css('nds-progress.progress')
        expect(progress).to have_css(
          '.progress__step[aria-current="step"] .progress__step-counter',
          text: '1 / 2',
        )
      end

      context 'with a method already configured' do
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

    context 'during sign-in (not account creation)' do
      let(:in_account_creation_flow) { false }

      it 'does not render the header progress stepper' do
        rendered
        expect(view.content_for(:nds_header_progress)).to be_blank
      end
    end
  end
end
