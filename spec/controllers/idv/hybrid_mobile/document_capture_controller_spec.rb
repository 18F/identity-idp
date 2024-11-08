require 'rails_helper'

RSpec.describe Idv::HybridMobile::DocumentCaptureController do
  let(:user) { create(:user) }

  let!(:document_capture_session) do
    DocumentCaptureSession.create!(
      user: user,
      requested_at: document_capture_session_requested_at,
    )
  end

  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  let(:document_capture_session_requested_at) { Time.zone.now }
  let(:document_capture_session_result_captured_at) { Time.zone.now + 1.second }
  let(:document_capture_session_result_success) { true }
  let(:idv_vendor) { Idp::Constants::Vendors::MOCK }

  before do
    stub_analytics

    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid

    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
  end

  describe 'before_actions' do
    it 'includes :check_valid_document_capture_session' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end

  describe '#show' do
    context 'with no user id in session' do
      let(:document_capture_session) { nil }
      let(:user) { nil }

      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'with a user id in session' do
      let(:analytics_name) { 'IdV: doc auth document_capture visited' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
          step: 'document_capture',
          selfie_check_required: false,
          liveness_checking_required: boolean,
        }
      end

      context 'when we try to use this controller but we should be using the Socure version' do
        let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

        it 'redirects to the Socure controller' do
          get :show

          expect(response).to redirect_to idv_hybrid_mobile_socure_document_capture_url
        end
      end

      it 'renders the show template' do
        expect(subject).to receive(:render).with(
          :show,
          locals: hash_including(
            document_capture_session_uuid: document_capture_session_uuid,
          ),
        ).and_call_original

        get :show

        expect(response).to render_template :show
      end

      context 'when selfie is required' do
        before do
          authn_context_result = Vot::Parser.new(vector_of_trust: 'Pb').parse
          allow(subject).to receive(:resolved_authn_context_result).and_return(authn_context_result)
        end

        it 'requests FE to display selfie' do
          expect(subject).to receive(:render).with(
            :show,
            locals: hash_including(
              document_capture_session_uuid: document_capture_session_uuid,
              doc_auth_selfie_capture: true,
            ),
          ).and_call_original

          get :show

          expect(response).to render_template :show
        end
      end

      it 'sends analytics_visited event' do
        get :show

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'updates DocAuthLog document_capture_view_count' do
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { get :show }.to(
          change { doc_auth_log.reload.document_capture_view_count }.from(0).to(1),
        )
      end

      context 'with expired DocumentCaptureSession' do
        let(:document_capture_session_requested_at) do
          Time.zone.now.advance(
            minutes: IdentityConfig.store.doc_capture_request_valid_for_minutes * -2,
          )
        end
        it 'redirects to root, displays flash, and deletes session' do
          get :show
          expect(response).to redirect_to(root_url)
          expect(session.delete('flash')).to be
          expect(session).to be_blank
        end
      end
    end

    context 'stored_result already exists' do
      before do
        stub_document_capture_session_result
      end

      it 'redirects to document capture complete' do
        get :show
        expect(response).to redirect_to idv_hybrid_mobile_capture_complete_url
      end

      context 'document capture re-requested' do
        let(:document_capture_session_result_captured_at) do
          document_capture_session_requested_at - 5.minutes
        end
        context 'with successful stored_result' do
          it 'renders the show template' do
            get :show
            expect(response).to render_template :show
          end
        end

        context 'with failed stored_result' do
          let(:document_capture_session_result_success) { false }
          it 'renders the show template' do
            get :show
            expect(response).to render_template :show
          end
        end
      end
    end
  end

  describe '#update' do
    before do
      stub_document_capture_session_result
    end

    context 'with no user id in session' do
      let(:user) { nil }
      let(:document_capture_session) { nil }
      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'with a user id in session' do
      let(:analytics_name) { 'IdV: doc auth document_capture submitted' }
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
          step: 'document_capture',
          liveness_checking_required: false,
          selfie_check_required: boolean,
        }
      end

      before do
        session[:doc_capture_user_id] = user.id
      end

      it 'tracks expected events' do
        get :show
        put :update

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'does not raise an exception when stored_result is nil' do
        allow(subject).to receive(:stored_result).and_return(nil)

        put :update
      end

      it 'redirects to CaptureComplete step' do
        put :update
        expect(response).to redirect_to idv_hybrid_mobile_capture_complete_url
      end

      context 'ocr confirmation pending' do
        before do
          subject.document_capture_session.ocr_confirmation_pending = true
        end

        it 'confirms ocr' do
          put :update
          expect(subject.document_capture_session.ocr_confirmation_pending).to be_falsey
        end
      end

      context 'selfie checks' do
        before do
          expect(controller).to receive(:selfie_requirement_met?).
            and_return(performed_if_needed)
        end

        context 'not performed' do
          let(:performed_if_needed) { false }

          it 'stays on hybrid mobile document capture' do
            put :update
            expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
          end
        end

        context 'performed' do
          let(:performed_if_needed) { true }

          it 'redirects to capture complete' do
            put :update
            expect(response).to redirect_to idv_hybrid_mobile_capture_complete_url
          end
        end
      end
    end
  end

  describe '#extra_view_variables' do
    subject(:extra_view_variables) { controller.extra_view_variables }

    it 'includes acuant a/b testing vars' do
      expect(controller).to receive(:acuant_sdk_upgrade_a_b_testing_variables).and_call_original
      controller.extra_view_variables
    end
  end

  def stub_document_capture_session_result
    allow_any_instance_of(DocumentCaptureSession).to receive(:load_result).and_return(
      DocumentCaptureSessionResult.new(
        id: 1234,
        pii: {
          state: 'WA',
        },
        attention_with_barcode: true,
        captured_at: document_capture_session_result_captured_at,
        doc_auth_success: document_capture_session_result_success,
        selfie_status: document_capture_session_result_success ? :success : :fail,
        success: document_capture_session_result_success,
      ),
    )
  end
end
