require 'rails_helper'

RSpec.describe 'idv/phone/new.html.erb' do
  let(:gpo_letter_available) { false }
  let(:proofing_with_superior_evidence) { false }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }

  let(:presenter) do
    Idv::PhonePresenter.new(
      gpo_letter_available:,
      proofing_with_superior_evidence:,
      url_options: {},
    )
  end

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:presenter).and_return(presenter)
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

  context 'user is proofing with superior evidence' do
    let(:proofing_with_superior_evidence) { true }

    it 'renders the superior evidence title and description' do
      expect(rendered).to have_text(t('titles.idv.phone_skip_verification'))
      expect(rendered).to have_text(t('idv.messages.phone.description_skip_verification'))
    end
  end

  context 'user is not proofing with superior evidence' do
    let(:proofing_with_superior_evidence) { false }

    it 'renders the superior evidence title and description' do
      expect(rendered).to have_text(t('titles.idv.phone'))
      expect(rendered).to have_text(t('idv.messages.phone.description'))
    end
  end
end
