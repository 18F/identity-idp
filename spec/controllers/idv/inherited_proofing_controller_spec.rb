require 'rails_helper'

describe Idv::InheritedProofingController do
  describe '#index' do
    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_inherited_proofing_step_url(step: :get_started)
    end
  end

  describe '#show' do
    it 'renders the correct template' do
      expect(subject).to receive(:render).with(
        template: 'layouts/flow_step',
        locals: hash_including(
          :flow_session,
          flow_namespace: 'idv',
          step_template: 'idv/inherited_proofing/get_started',
          step_indicator: hash_including(
            :steps,
            current_step: :getting_started,
          ),
        ),
      ).and_call_original

      get :show, params: { step: 'get_started' }
    end

    it 'redirects to the configured next step' do
      mock_next_step(:some_next_step)
      get :show, params: { step: 'getting_started' }

      expect(response).to redirect_to idv_inherited_proofing_step_url(:some_next_step)
    end

    it 'redirects to the first step if a non-existent step is given' do
      get :show, params: { step: 'non_existent_step' }

      expect(response).to redirect_to idv_inherited_proofing_step_url(step: :get_started)
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::InheritedProofingFlow).to receive(:next_step).and_return(step)
  end
end
