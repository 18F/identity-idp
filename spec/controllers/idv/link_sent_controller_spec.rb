require 'rails_helper'

RSpec.describe Idv::LinkSentController do
  include IdvHelper

  let(:flow_session) { {} }

  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
    subject.idv_session.flow_path = 'hybrid'
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end

    it 'checks that hybrid_handoff is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_hybrid_handoff_complete,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth link_sent visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        irs_reproofing: false,
        step: 'link_sent',
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog link_sent_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.link_sent_view_count }.from(0).to(1),
      )
    end

    context '#confirm_hybrid_handoff_complete' do
      context 'no flow_path' do
        it 'redirects to idv_hybrid_handoff_url' do
          subject.idv_session.flow_path = nil

          get :show

          expect(response).to redirect_to(idv_hybrid_handoff_url)
        end
      end

      context 'flow_path is standard' do
        it 'redirects to idv_document_capture_url' do
          subject.idv_session.flow_path = 'standard'

          get :show

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end
    end

    context 'with pii in flow_session' do
      it 'redirects to ssn step' do
        flow_session[:pii_from_doc] = Idp::Constants::MOCK_IDV_APPLICANT
        get :show

        expect(response).to redirect_to(idv_ssn_url)
      end
    end

    context 'with pii in idv_session' do
      it 'redirects to ssn step' do
        subject.idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT
        get :show

        expect(response).to redirect_to(idv_ssn_url)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth link_sent submitted' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        irs_reproofing: false,
        step: 'link_sent',
      }.merge(ab_test_args)
    end

    it 'sends analytics_submitted event' do
      put :update

      expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
    end

    context 'check results' do
      let(:load_result) { double('load result') }
      let(:session_canceled_at) { nil }
      let(:load_result_success) { true }

      before do
        allow(load_result).to receive(:pii_from_doc).and_return(Idp::Constants::MOCK_IDV_APPLICANT)
        allow(load_result).to receive(:attention_with_barcode?).and_return(false)

        allow(load_result).to receive(:success?).and_return(load_result_success)

        document_capture_session = DocumentCaptureSession.create!(
          user: user,
          cancelled_at: session_canceled_at,
        )
        allow(document_capture_session).to receive(:load_result).and_return(load_result)
        allow(subject).to receive(:document_capture_session).and_return(document_capture_session)
      end

      it 'redirects to ssn page when successful' do
        put :update

        expect(response).to redirect_to(idv_ssn_url)

        pc = ProofingComponent.find_by(user_id: user.id)
        expect(pc.document_check).to eq('mock')
        expect(pc.document_type).to eq('state_id')
      end

      context 'document capture session canceled' do
        let(:session_canceled_at) { Time.zone.now }
        let(:error_message) { t('errors.doc_auth.document_capture_cancelled') }

        before do
          expect(FormResponse).to receive(:new).with(
            { success: false,
              errors: { message: error_message } },
          )
        end

        it 'redirects to hybrid_handoff page' do
          put :update

          expect(response).to redirect_to(idv_hybrid_handoff_url)
          expect(flash[:error]).to eq(error_message)
        end
      end

      context 'document capture session result fails' do
        let(:load_result_success) { false }

        it 'returns an empty response' do
          put :update

          expect(response).to have_http_status(204)
          expect(flash[:error]).to eq(t('errors.doc_auth.phone_step_incomplete'))
        end
      end
    end
  end
end
