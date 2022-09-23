require 'rails_helper'

shared_examples 'the flow steps work correctly' do
  describe '#index' do
    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_inherited_proofing_step_url(step: :get_started)
    end

    context 'when the inherited proofing feature flag is disabled' do
      it 'returns 404 not found' do
        allow(IdentityConfig.store).to receive(:inherited_proofing_enabled).and_return(false)

        get :index

        expect(response).to have_http_status(:not_found)
      end
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
end

def mock_next_step(step)
  allow_any_instance_of(Idv::Flows::InheritedProofingFlow).to receive(:next_step).and_return(step)
end

describe Idv::InheritedProofingController do
  let(:sp) { nil }
  let(:user) { build(:user) }

  before do
    allow(controller).to receive(:current_sp).and_return(sp)
    stub_sign_in(user)
  end

  context 'when VA inherited proofing mock is enabled' do
    before do
      allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return(true)
    end

    it_behaves_like 'the flow steps work correctly'
  end

  context 'when VA inherited proofing mock is not enabled' do
    before do
      allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return(false)
    end

    it_behaves_like 'the flow steps work correctly'
  end
end
