require 'rails_helper'

describe 'idv/otp_delivery_method/new.html.erb' do
  let(:gpo_letter_available) { false }
  let(:step_indicator_steps) { Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS }

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:gpo_letter_available).and_return(gpo_letter_available)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
  end

  subject(:rendered) { render template: 'idv/otp_delivery_method/new' }

  context 'gpo letter available' do
    let(:gpo_letter_available) { true }

    it 'renders troubleshooting options' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.change_phone_number'))
      expect(rendered).to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'gpo letter not available' do
    let(:gpo_letter_available) { false }

    it 'renders troubleshooting options' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.change_phone_number'))
      expect(rendered).not_to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end

    it 'disables problematic vendor option' do
      expect(rendered).to have_field('otp_delivery_preference', with: :voice, disabled: false)
      expect(rendered).to have_field('otp_delivery_preference', with: :sms, disabled: true)
    end
  end
end
