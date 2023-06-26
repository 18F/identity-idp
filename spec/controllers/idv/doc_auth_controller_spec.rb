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

      expect(response).to redirect_to idv_doc_auth_step_url(step: :welcome)
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
    it 'renders the correct template' do
      expect(subject).to receive(:render).with(
        template: 'layouts/flow_step',
        locals: hash_including(
          :flow_session,
          step_template: 'idv/doc_auth/welcome',
          flow_namespace: 'idv',
        ),
      ).and_call_original

      mock_next_step(:welcome)
      get :show, params: { step: 'welcome' }
    end

    it 'renders a 404 with a non existent step' do
      get :show, params: { step: 'foo' }

      expect(response).to_not be_not_found
    end

    it 'tracks analytics' do
      result = {
        step: 'welcome',
        flow_path: 'standard',
        irs_reproofing: false,
        step_count: 1,
        analytics_id: 'Doc Auth',
        acuant_sdk_upgrade_ab_test_bucket: :default,
      }

      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth welcome visited', result
      )
    end

    it 'increments the analytics step counts on subsequent submissions' do
      get :show, params: { step: 'welcome' }
      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: doc auth welcome visited',
        hash_including(
          step: 'welcome',
          step_count: 1,
          acuant_sdk_upgrade_ab_test_bucket: :default,
        ),
      )
      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: doc auth welcome visited',
        hash_including(step: 'welcome', step_count: 2),
      )
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

        expect(response).to redirect_to idv_agreement_url
      end
    end
  end

  describe '#update' do
    it 'tracks analytics' do
      mock_next_step(:back_image)
      allow_any_instance_of(Flow::BaseFlow).to \
        receive(:flow_session).and_return(pii_from_doc: {})
      result = {
        success: true,
        errors: {},
        step: 'welcome',
        flow_path: 'standard',
        step_count: 1,
        irs_reproofing: false,
        analytics_id: 'Doc Auth',
        acuant_sdk_upgrade_ab_test_bucket: :default,
      }

      put :update, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth welcome submitted', result
      )
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
        put :update, params: { step: 'ssn' }

        expect(response).to redirect_to idv_agreement_url
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::DocAuthFlow).to receive(:next_step).and_return(step)
  end
end
