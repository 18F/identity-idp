require 'rails_helper'

RSpec.describe Idv::LinkSentController do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
    subject.idv_session.flow_path = 'hybrid'
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::LinkSentController.step_info).to be_valid
    end
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

    it 'checks that step is allowed' do
      expect(subject).to have_actions(
        :before,
        :confirm_step_allowed,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth link_sent visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
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

    context 'no flow_path in idv_session' do
      it 'redirects to idv_hybrid_handoff_url' do
        subject.idv_session.flow_path = nil

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end

      context 'flow_path is standard' do
        it 'redirects to idv_document_capture_url' do
          subject.idv_session.welcome_visited = true
          subject.idv_session.idv_consent_given = true
          subject.idv_session.flow_path = 'standard'

          get :show

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      context 'with pii in idv_session' do
        it 'allows the back button and does not redirect' do
          subject.idv_session.pii_from_doc = Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
          get :show

          expect(response).to render_template :show
        end
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth link_sent submitted' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        step: 'link_sent',
      }.merge(ab_test_args)
    end

    it 'invalidates future steps' do
      subject.idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT
      expect(subject).to receive(:clear_future_steps!).and_call_original

      put :update
      expect(subject.idv_session.applicant).to be_nil
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
        allow(load_result).to receive(:selfie_check_performed?).and_return(false)

        document_capture_session = DocumentCaptureSession.create!(
          user: user,
          cancelled_at: session_canceled_at,
        )
        allow(document_capture_session).to receive(:load_result).and_return(load_result)
        allow(subject).to receive(:document_capture_session).and_return(document_capture_session)
      end

      context 'document capture session successful' do
        it 'redirects to ssn page' do
          put :update

          expect(response).to redirect_to(idv_ssn_url)

          pc = ProofingComponent.find_by(user_id: user.id)
          expect(pc.document_check).to eq('mock')
          expect(pc.document_type).to eq('state_id')
        end

        context 'redo document capture' do
          before do
            subject.idv_session.redo_document_capture = true
          end
          it 'resets redo_document capture to nil in idv_session' do
            put :update
            expect(subject.idv_session.redo_document_capture).to be_nil
          end
        end

        context 'selfie checks' do
          before do
            expect(controller).to receive(:selfie_requirement_met?).
              and_return(performed_if_needed)
          end

          context 'not performed' do
            let(:performed_if_needed) { false }

            it 'flashes an error and does not redirect' do
              put :update

              expect(flash[:error]).to eq t('errors.doc_auth.phone_step_incomplete')
              expect(response.status).to eq(204)
            end
          end

          context 'performed' do
            let(:performed_if_needed) { true }

            it 'redirects to ssn' do
              put :update
              expect(flash[:error]).to eq nil
              expect(response).to redirect_to idv_ssn_url
            end
          end
        end
      end

      context 'document capture session canceled' do
        let(:session_canceled_at) { Time.zone.now }
        let(:error_message) { t('errors.doc_auth.document_capture_canceled') }

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
