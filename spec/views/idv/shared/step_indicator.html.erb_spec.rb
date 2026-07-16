# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'idv/shared/_step_indicator.html.erb' do
  let(:steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }

  before do
    allow(view).to receive(:step_indicator_steps).and_return(steps)
  end

  def progress_component
    view.instance_variable_get(:@ads_progress_component)
  end

  it 'assigns ProgressComponent from StepIndicatorConcern step lists' do
    render partial: 'idv/shared/step_indicator',
           locals: { current_step: :verify_info }

    expect(progress_component).to be_a(ProgressComponent)
    expect(progress_component.current_step).to eq(2)
    expect(progress_component.steps).to include(t('step_indicator.flows.idv.verify_info'))
    expect(progress_component.steps.first).to eq(t('step_indicator.flows.idv.getting_started'))
  end

  it 'uses an explicit steps list for alternate IDV flows' do
    render partial: 'idv/shared/step_indicator',
           locals: {
             current_step: :verify_address,
             steps: Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO,
           }

    expect(progress_component.current_step).to eq(3)
    expect(progress_component.steps).to include(t('step_indicator.flows.idv.verify_address'))
    expect(progress_component.steps).to include(t('step_indicator.flows.idv.secure_account'))
  end

  it 'assigns nothing when current_step is not in the list' do
    render partial: 'idv/shared/step_indicator',
           locals: { current_step: :not_a_real_step }

    expect(progress_component).to be_nil
  end
end
