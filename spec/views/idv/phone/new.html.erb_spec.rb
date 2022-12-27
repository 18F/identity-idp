require 'rails_helper'

describe 'idv/phone/new.html.erb' do
  let(:gpo_letter_available) { false }
  let(:step_indicator_steps) { Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS }

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
end
