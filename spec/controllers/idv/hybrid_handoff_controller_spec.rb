require 'rails_helper'

RSpec.describe Idv::HybridHandoffController do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    subject.idv_session.idv_consent_given = true
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

    it 'checks that agreement step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_agreement_step_complete,
      )
    end

    it 'checks that hybrid_handoff is needed' do
      expect(subject).to have_actions(
        :before,
        :confirm_hybrid_handoff_needed,
      )
    end

    it 'includes redirect for phone_question ab test before_action' do
      expect(subject).to have_actions(
        :before,
        :maybe_redirect_for_phone_question_ab_test,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth hybrid handoff visited' }
    let(:analytics_args) do
      {
        step: 'hybrid_handoff',
        analytics_id: 'Doc Auth',
        redo_document_capture: nil,
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog upload_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.upload_view_count }.from(0).to(1),
      )
    end

    context 'agreement step is not complete' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to idv_agreement_url' do
        get :show

        expect(response).to redirect_to(idv_agreement_url)
      end
    end

    context 'hybrid_handoff already visited' do
      it 'redirects to document_capture in standard flow' do
        subject.idv_session.flow_path = 'standard'

        get :show

        expect(response).to render_template :show
      end

      it 'redirects to link_sent in hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'

        get :show

        expect(response).to render_template :show
      end
    end

    context 'redo document capture' do
      it 'does not redirect in standard flow' do
        subject.idv_session.flow_path = 'standard'

        get :show, params: { redo: true }

        expect(response).to render_template :show
      end

      it 'does not redirect in hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'

        get :show, params: { redo: true }

        expect(response).to render_template :show
      end

      context 'idv_session.skip_hybrid_handoff? is true' do
        before do
          subject.idv_session.skip_hybrid_handoff = true
        end
        it 'redirects to document_capture' do
          subject.idv_session.flow_path = 'standard'
          get :show, params: { redo: true }

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      it 'adds redo_document_capture to analytics' do
        get :show, params: { redo: true }

        analytics_args[:redo_document_capture] = true
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      context 'user has already completed verify info' do
        before do
          subject.idv_session.mark_verify_info_step_complete!
        end

        it 'does not set redo_document_capture to true in idv_session' do
          get :show, params: { redo: true }

          expect(subject.idv_session.redo_document_capture).not_to be_truthy
        end

        it 'does not add redo_document_capture to analytics' do
          get :show, params: { redo: true }

          expect(@analytics).not_to have_logged_event(analytics_name)
        end

        it 'redirects to review' do
          get :show, params: { redo: true }

          expect(response).to redirect_to(idv_enter_password_url)
        end
      end
    end

    context 'hybrid flow is not available' do
      before do
        allow(FeatureManagement).to receive(:idv_allow_hybrid_flow?).and_return(false)
      end

      it 'redirects the user straight to document capture' do
        get :show
        expect(response).to redirect_to(idv_document_capture_url)
      end
      it 'does not set idv_session.skip_hybrid_handoff' do
        expect do
          get :show
        end.not_to change {
          subject.idv_session.skip_hybrid_handoff?
        }.from(false)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth hybrid handoff submitted' }

    context 'hybrid flow' do
      let(:analytics_args) do
        {
          success: true,
          errors: { message: nil },
          destination: :link_sent,
          flow_path: 'hybrid',
          step: 'hybrid_handoff',
          analytics_id: 'Doc Auth',
          redo_document_capture: nil,
          skip_hybrid_handoff: nil,
          irs_reproofing: false,
          telephony_response: {
            errors: {},
            message_id: 'fake-message-id',
            request_id: 'fake-message-request-id',
            success: true,
          },
        }.merge(ab_test_args)
      end

      let(:params) do
        {
          type: 'mobile',
          doc_auth: { phone: '202-555-5555' },
        }
      end

      let(:document_capture_session_uuid) { '09228b6d-dd39-4925-bf82-b69104095517' }

      it 'sends analytics_submitted event for hybrid' do
        put :update, params: params

        expect(subject.idv_session.phone_for_mobile_flow).to eq('+1 202-555-5555')
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      before do
        subject.idv_session.document_capture_session_uuid = document_capture_session_uuid
      end

      it 'sends a doc auth link' do
        expect(Telephony).to receive(:send_doc_auth_link).with(
          hash_including(
            link: a_string_including(document_capture_session_uuid),
          ),
        ).and_call_original

        put :update, params: params
      end
    end

    context 'desktop flow' do
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          destination: :document_capture,
          flow_path: 'standard',
          step: 'hybrid_handoff',
          analytics_id: 'Doc Auth',
          redo_document_capture: nil,
          skip_hybrid_handoff: nil,
          irs_reproofing: false,
        }.merge(ab_test_args)
      end

      let(:params) do
        {
          type: 'desktop',
        }
      end

      it 'sends analytics_submitted event for desktop' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'sends irs_attempts_api_tracking' do
        expect(@irs_attempts_api_tracker).to receive(
          :idv_document_upload_method_selected,
        ).with({ upload_method: 'desktop' })

        put :update, params: { type: 'desktop' }
      end
    end
  end

  context '#maybe_redirect_for_phone_question_ab_test' do
    context 'A/B test specifies phone question page' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:bypass_phone_question)
      end

      it 'does not redirect users away from hybrid handoff page' do
        get :show

        expect(response).to render_template :show
        expect(response.status).to eq(200)
      end
    end

    context 'A/B test specifies phone question page' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:show_phone_question)
      end

      it 'redirect users to phone question page' do
        get :show

        expect(response).to redirect_to(idv_phone_question_url)
      end

      context 'when user comes from phone_question page' do
        before do
          subject.idv_session.phone_with_camera = false
        end

        it 'does not redirect users away from hybrid handoff page' do
          get :show

          expect(response).to render_template :show
          expect(response.status).to eq(200)
        end
      end
    end

    context 'A/B test specifies some other value' do
      before do
        allow(controller).to receive(:phone_question_ab_test_bucket).
          and_return(:something_else)
      end

      it 'does not redirect users away from hybrid handoff page' do
        get :show

        expect(response).to render_template :show
        expect(response.status).to eq(200)
      end
    end
  end
end
