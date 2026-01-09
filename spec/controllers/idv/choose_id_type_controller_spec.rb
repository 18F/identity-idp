require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, user:)
  end

  before do
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    stub_sign_in(user)
    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    stub_analytics
  end

  describe '#step info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::ChooseIdTypeController.step_info).to be_valid
    end
  end

  describe 'before actions' do
    it 'includes confirm_steps_allowed' do
      expect(subject).to have_actions(
        :before,
        :confirm_step_allowed,
      )
    end
  end

  describe '#show' do
    context 'when the user passes all preconditions' do
      let(:analytics_name) { :idv_doc_auth_choose_id_type_visited }
      let(:analytics_args) do
        {
          step: 'choose_id_type',
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
        }
      end

      before do
        subject.idv_session.flow_path = 'standard'
        subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
        get :show
      end

      it 'renders the shared choose_id_type template' do
        expect(response).to render_template 'idv/shared/choose_id_type'
      end

      it 'sends analytics_visited event' do
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end

    context 'when the user does not have a flow path' do
      before do
        subject.idv_session.flow_path = nil
        get :show
      end

      it 'does not render the shared choose_id_type template' do
        expect(response).not_to render_template 'idv/shared/choose_id_type'
      end

      it 'responds with a redirect' do
        expect(response.status).to be(302)
      end
    end
  end

  describe '#update' do
    let(:chosen_id_type) { 'drivers_license' }
    let(:analytics_name) { :idv_doc_auth_choose_id_type_submitted }
    let(:analytics_args) do
      {
        success: true,
        step: 'choose_id_type',
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        chosen_id_type: chosen_id_type,
      }
    end

    let(:params) do
      { doc_auth: { choose_id_type_preference: chosen_id_type } }
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update, params: params
    end

    it 'sends analytics submitted event for id choice' do
      put :update, params: params

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'user selects drivers license' do
      it 'redirects to document capture session' do
        put :update, params: params

        expect(response).to redirect_to(idv_document_capture_url)
      end
    end

    context 'user selects passport' do
      let(:chosen_id_type) { 'passport' }

      it 'sets document_capture_session to passport requested' do
        put :update, params: params

        expect(subject.document_capture_session.passport_requested?).to eq(true)
      end

      # currently we do not have a passport route so it redirects to ipp route
      # change when the new passport is added
      it 'redirects to passport document capture' do
        put :update, params: params

        expect(response).to redirect_to(idv_document_capture_url)
      end
    end

    context 'user selects mdl' do
      let(:chosen_id_type) { Idp::Constants::DocumentTypes::MDL }

      before do
        allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(true)
      end

      it 'redirects to mdl verification page' do
        put :update, params: params

        expect(response).to redirect_to(idv_mdl_url)
      end

      it 'sets skip_doc_auth_from_how_to_verify to true' do
        put :update, params: params

        expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to eq(true)
      end
    end
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::ChooseIdTypeController.step_info).to be_valid
    end

    describe '#undo_step' do
      before do
        subject.document_capture_session.update!(passport_status: 'requested')
      end

      context 'when idv_session has a document_capture_session_uuid' do
        before do
          subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
        end

        before do
          described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
        end

        it 'resets relevant fields on idv_session to nil' do
          subject.document_capture_session.reload
          expect(subject.document_capture_session.passport_requested?).to eq(false)
        end
      end

      context 'when idv_session does not have a document_capture_session_uuid' do
        before do
          subject.idv_session.document_capture_session_uuid = nil
          described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
        end

        it 'does not update the passport status in the document capture session' do
          expect(subject.document_capture_session.reload.passport_status).to eq('requested')
        end
      end
    end
  end
end
