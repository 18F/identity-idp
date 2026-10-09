require 'rails_helper'

RSpec.describe 'idv/otp_verification/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nds_layout) { false }
  let(:delivery_method) { :sms }
  let(:phone_session) do
    Struct.new(:phone, :delivery_method, :code).new('(202) 555-1212', delivery_method, nil)
  end
  let(:idv_session) { Struct.new(:user_phone_confirmation_session).new(phone_session) }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:step_indicator_steps)
      .and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
    @presenter = Idv::OtpVerificationPresenter.new(idv_session:)
    @otp_code_length = TwoFactorAuthenticatable::DIRECT_OTP_LENGTH
    render
  end

  it 'renders the legacy heading and submit' do
    expect(rendered).to have_css('h1', text: t('two_factor_authentication.header_text'))
    expect(rendered).to have_button(t('forms.buttons.submit.default'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the code card with the segmented OTP input and continue' do
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('two_factor_authentication.header_text'),
      )
      expect(rendered).to have_css('.auth__intro-description strong', text: '(202) 555-1212')
      expect(rendered).to have_text(
        strip_tags(
          t('nds.otp_verification.sms.code_sent_html', number_html: '(202) 555-1212'),
        ),
      )
      expect(rendered).to have_css('lg-nds-input-otp .input-otp__slot', count: 6)
      expect(rendered).to have_css(
        "#code[required][pattern='[a-zA-Z0-9]{6}']:not([inputmode])",
      )
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]:not([form])',
        text: t('forms.buttons.continue'),
      )
    end

    it 'submits resend through its own ungated form and offers another number' do
      expect(rendered).to have_css(
        '.auth__actions button[form="idv-resend-otp-form"][formnovalidate]',
        text: t('links.two_factor_authentication.send_another_code'),
      )
      expect(rendered).to have_css(
        "form#idv-resend-otp-form[action='#{idv_resend_otp_path}']",
        visible: :all,
      )
      expect(rendered).to have_link(
        t('forms.two_factor.try_again'),
        href: idv_phone_path(step: 'phone_otp_verification'),
      )
    end

    it 'includes the OTP input and submit-gate javascript packs' do
      expect(view).to receive(:javascript_packs_tag_once)
        .with('nds-input-otp', 'nds-auth-submit-gate', preload_links_header: false)

      render
    end

    context 'when the code was delivered by voice' do
      let(:delivery_method) { :voice }

      it 'describes the code as called in' do
        expect(rendered).to have_text(
          strip_tags(
            t('nds.otp_verification.voice.code_sent_html', number_html: '(202) 555-1212'),
          ),
        )
        expect(rendered).not_to have_text(
          strip_tags(
            t('nds.otp_verification.sms.code_sent_html', number_html: '(202) 555-1212'),
          ),
        )
      end
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end

    context 'with an invalid code flash' do
      before do
        flash[:error] = t('two_factor_authentication.invalid_otp')
        render
      end

      it 'renders the invalid-code alert' do
        expect(rendered).to have_text(t('nds.otp_verification.invalid_otp_heading'))
      end
    end
  end
end
