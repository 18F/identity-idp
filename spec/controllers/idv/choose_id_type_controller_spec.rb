require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(:document_capture_session, user:, passport_status: 'allowed')
  end

  before do
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
    it 'includes redirect_if_passport_not_available before_action' do
      expect(subject).to have_actions(
        :before,
        :redirect_if_passport_not_available,
      )
    end
  end

  describe '#show' do
    context 'passport is not available' do
      it 'redirects to how to verify' do
        subject.idv_session.passport_allowed = false

        get :show

        expect(response).to redirect_to(idv_how_to_verify_url)
      end
    end

    context 'passport is available' do
      let(:analytics_name) { :idv_doc_auth_choose_id_type_visited }
      let(:analytics_args) do
        {
          step: 'choose_id_type',
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
        }
      end

      it 'renders the show template' do
        subject.idv_session.passport_allowed = true

        get :show

        expect(response).to render_template :show
      end

      it 'sends analytics_visited event' do
        subject.idv_session.passport_allowed = true

        get :show

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
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

    before do
      allow(subject.idv_session).to receive(:passport_allowed).and_return(true)
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
      it 'document_capture_session passport remains allowed' do
        put :update, params: params

        expect(subject.document_capture_session.passport_allowed?).to eq(true)
      end

      context 'when previously requested' do
        before do
          subject.document_capture_session.update!(passport_status: 'requested')
        end

        it 'sets document_capture_session to passport allowed' do
          put :update, params: params

          expect(subject.document_capture_session.passport_allowed?).to eq(true)
        end
      end

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
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::ChooseIdTypeController.step_info).to be_valid
    end

    describe '#undo_step' do
      before do
        subject.document_capture_session.update!(passport_status: 'requested')
      end

      it 'resets relevant fields on idv_session to nil' do
        described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)

        subject.document_capture_session.reload
        expect(subject.document_capture_session.passport_requested?).to eq(false)
        expect(subject.document_capture_session.passport_allowed?).to eq(false)
      end
    end
  end
end
