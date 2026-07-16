require 'rails_helper'

RSpec.describe 'idv/phone/new.html.erb' do
  let(:gpo_letter_available) { false }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:gpo_letter_available).and_return(gpo_letter_available)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
  end

  subject(:rendered) { render template: 'idv/phone/new' }

  context 'gpo letter available' do
    let(:gpo_letter_available) { true }

    it 'renders no US phone number option' do
      expect(rendered).to have_link(
        t('idv.buttons.phone.no_us_phone_number'),
        href: idv_request_letter_path,
      )
    end
  end

  context 'gpo letter not available' do
    let(:gpo_letter_available) { false }

    it 'does not render no US phone number option' do
      expect(rendered).not_to have_link(t('idv.buttons.phone.no_us_phone_number'))
    end
  end
end
