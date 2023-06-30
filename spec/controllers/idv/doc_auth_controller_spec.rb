require 'rails_helper'

RSpec.describe Idv::DocAuthController do
  include DocAuthHelper

  let(:user) { build(:user) }

  describe 'before_actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :initialize_flow_state_machine,
        :ensure_correct_step,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  let(:user) { build(:user) }

  before do |example|
    stub_sign_in(user) if user
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe 'unauthenticated' do
    let(:user) { nil }

    it 'redirects to the root url' do
      get :index

      expect(response).to redirect_to root_url
    end
  end

  describe '#index' do
    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_welcome_url
    end

    context 'with pending in person enrollment' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'redirects to in person ready to verify page' do
        get :index

        expect(response).to redirect_to idv_in_person_ready_to_verify_url
      end
    end
  end

  describe '#show' do
    it 'renders a 404 with a non existent step' do
      get :show, params: { step: 'foo' }

      expect(response).to_not be_not_found
    end

    context 'with an existing applicant' do
      before do
        idv_session = Idv::Session.new(
          user_session: controller.user_session,
          current_user: user,
          service_provider: nil,
        )
        idv_session.applicant = {}
        allow(controller).to receive(:idv_session).and_return(idv_session)
      end

      it 'finishes the flow' do
        get :show, params: { step: 'welcome' }

        expect(response).to redirect_to idv_welcome_url
      end
    end
  end

  describe '#update' do
    context 'with an existing applicant' do
      before do
        idv_session = Idv::Session.new(
          user_session: controller.user_session,
          current_user: user,
          service_provider: nil,
        )
        idv_session.applicant = {}
        allow(controller).to receive(:idv_session).and_return(idv_session)
      end

      it 'finishes the flow' do
        put :update, params: { step: 'welcome' }

        expect(response).to redirect_to idv_welcome_url
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::DocAuthFlow).to receive(:next_step).and_return(step)
  end
end
