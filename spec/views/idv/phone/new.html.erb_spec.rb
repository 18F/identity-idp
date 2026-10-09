require 'rails_helper'

RSpec.describe 'idv/phone/new.html.erb' do
  let(:gpo_letter_available) { false }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:gpo_letter_available).and_return(gpo_letter_available)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
  end

  subject(:rendered) { render template: 'idv/phone/new' }

  context 'gpo letter available' do
    let(:gpo_letter_available) { true }

    it 'renders troubleshooting options' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.learn_more_verify_by_phone'))
      expect(rendered).to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'gpo letter not available' do
    let(:gpo_letter_available) { false }

    it 'renders troubleshooting options' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.learn_more_verify_by_phone'))
      expect(rendered).not_to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the phone card with the pill, delivery radios and send-code submit' do
      expect(rendered).to have_css('.auth--form-page h1', text: t('titles.idv.phone'))
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.idv_phone.info'))
      expect(rendered).to have_css('.usa-phone-input input[name="idv_phone_form[phone]"]')
      expect(rendered).to have_css(
        'input.radio__input[name="idv_phone_form[otp_delivery_preference]"]',
        count: 2, visible: :all,
      )
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.send_one_time_code'),
      )
      expect(rendered).to have_css('form[data-form-steps-wait]')
    end

    it 'does not offer verify by mail without a letter' do
      expect(rendered).not_to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end

    it 'renders the failed-number alert hidden, wired for the toggle script' do
      expect(rendered).to have_css(
        '#phone-already-submitted-alert[hidden][data-failed-phone-numbers="[]"] .usa-alert',
        text: t('idv.messages.phone.failed_number.alert_text'),
        visible: :all,
      )
      expect(rendered).not_to have_css('#phone-already-submitted-alert')
    end

    it 'does not mark any numbers as failed on the phone group by default' do
      expect(rendered).to have_css('.usa-phone-input-group[data-nds-phone]')
      expect(rendered).not_to have_css('.usa-phone-input-group[data-nds-phone-failed-numbers]')
    end

    context 'with previously failed numbers' do
      before do
        @idv_form = Idv::PhoneForm.new(
          user: build_stubbed(:user),
          previous_params: nil,
          failed_phone_numbers: ['+12025550199'],
        )
      end

      it 'hands the failed numbers to the phone group so they cannot be resubmitted' do
        expect(rendered).to have_css(
          '.usa-phone-input-group[data-nds-phone-failed-numbers=\'["+12025550199"]\']',
        )
        group = Nokogiri::HTML(rendered).at_css('.usa-phone-input-group')
        messages = JSON.parse(group['data-nds-phone-messages'])
        expect(messages['failedNumber']).to eq(t('idv.messages.phone.failed_number.alert_text'))
      end
    end

    context 'gpo letter available' do
      let(:gpo_letter_available) { true }

      it 'offers verify by mail as a tertiary action' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button--tertiary',
          text: t('idv.troubleshooting.options.verify_by_mail'),
        )
      end
    end

    it 'sets the verification header progress' do
      rendered
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end
  end
end
