require 'rails_helper'

RSpec.describe Idv::HowToVerifyController do
  let(:user) { create(:user) }
  let(:enabled) { true }
  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { enabled }
    stub_sign_in(user)
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::HowToVerifyController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { :idv_doc_auth_how_to_verify_visited }
    let(:analytics_args) do
      {
        step: 'how_to_verify',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
      }.merge(ab_test_args)
    end
    it 'renders the show template' do
      get :show

      expect(subject.idv_session.skip_doc_auth).to be_nil
      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
    end

    context 'agreement step not completed' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to agreement path' do
        get :show

        expect(response).to redirect_to idv_agreement_path
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { :idv_doc_auth_how_to_verify_submitted }
    context 'no selection made' do
      let(:analytics_args) do
        {
          step: 'how_to_verify',
          analytics_id: 'Doc Auth',
          skip_hybrid_handoff: nil,
          irs_reproofing: false,
          error_details: { selection: { blank: true } },
          errors: { selection: ['Select a way to verify your identity.'] },
          success: false,
        }.merge(ab_test_args)
      end
      let(:params) do
        {
          idv_how_to_verify_form: { selection: selection },
        }
      end
      let(:selection) { 'remote' }

      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)
        
        put :update
      end

      it 'sends analytics_submitted event when nothing is selected' do
        put :update

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end
    end

    context 'in-person proofing is selected' do
      let(:selection) do
        { 'selection' => 'ipp' }
      end
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          skip_hybrid_handoff: nil,
          step: 'how_to_verify',
          irs_reproofing: false,
          errors: {},
          success: true,
        }.merge(selection).merge(ab_test_args)
      end
      let(:params) do
        {
          idv_how_to_verify_form: { selection: 'ipp' },
        }
      end

      it 'sends analytics_submitted event when ipp is selected' do
        put :update, params: params

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end
    end

    context 'remote proofing is selected' do
      let(:selection) do
        { 'selection' => 'remote' }
      end
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          skip_hybrid_handoff: nil,
          step: 'how_to_verify',
          irs_reproofing: false,
          errors: {},
          success: true,
        }.merge(selection).merge(ab_test_args)
      end
      let(:params) do
        {
          idv_how_to_verify_form: { selection: 'remote' },
        }
      end

      it 'sends analytics_submitted event when remote proofing is selected' do
        put :update, params: params

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end
    end

    context 'remote' do
      it 'sets skip doc auth on idv session to false and redirects to hybrid handoff' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth).to be false
        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end

    context 'ipp' do
      let(:selection) { 'ipp' }

      it 'sets skip doc auth on idv session to true and redirects to document capture' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth).to be true
        expect(response).to redirect_to(idv_document_capture_url)
      end
    end

    context 'undo/back' do
      it 'sets skip_doc_auth to nil and does not redirect' do
        put :update, params: { undo_step: true }

        expect(subject.idv_session.skip_doc_auth).to be_nil
        expect(response).to redirect_to(idv_how_to_verify_url)
      end
    end
  end
end
