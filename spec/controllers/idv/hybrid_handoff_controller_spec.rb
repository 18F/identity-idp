require 'rails_helper'

RSpec.describe Idv::HybridHandoffController do
  include IdvHelper

  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    subject.user_session['idv/doc_auth'] = {}
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
        :check_for_outage,
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
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth hybrid handoff visited' }
    let(:analytics_args) do
      {
        step: 'hybrid_handoff',
        analytics_id: 'Doc Auth',
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

        expect(response).to redirect_to(idv_document_capture_url)
      end

      it 'redirects to link_sent in hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'

        get :show

        expect(response).to redirect_to(idv_link_sent_url)
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

      it 'redirects to document_capture on a mobile device' do
        subject.idv_session.flow_path = 'standard'
        subject.user_session['idv/doc_auth'][:skip_upload_step] = true

        get :show, params: { redo: true }

        expect(response).to redirect_to(idv_document_capture_url)
      end

      it 'adds redo_document_capture to analytics' do
        get :show, params: { redo: true }

        analytics_args[:redo_document_capture] = true
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
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
          irs_reproofing: false,
          telephony_response: {
            errors: {},
            message_id: 'fake-message-id',
            request_id: 'fake-message-request-id',
            success: true,
          },
        }.merge(ab_test_args)
      end

      it 'sends analytics_submitted event for hybrid' do
        put :update, params: { doc_auth: { phone: '202-555-5555' } }

        expect(subject.idv_session.phone_for_mobile_flow).to eq('+1 202-555-5555')
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
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
          irs_reproofing: false,
          skip_upload_step: false,
        }.merge(ab_test_args)
      end

      it 'sends analytics_submitted event for desktop' do
        put :update, params: { type: 'desktop' }

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
end
