require 'rails_helper'

describe Idv::HybridHandoffController do
  include IdvHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    subject.user_session['idv/doc_auth'] = { 'Idv::Steps::AgreementStep' => true }
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
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
    let(:analytics_name) { 'IdV: doc auth upload visited' }
    let(:analytics_args) do
      { step: 'upload',
        analytics_id: 'Doc Auth',
        irs_reproofing: false }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog document_capture_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.upload_view_count }.from(0).to(1),
      )
    end

    context 'agreement step is not complete' do
      it 'redirects to idv_doc_auth_url' do
        subject.user_session['idv/doc_auth']['Idv::Steps::AgreementStep'] = nil

        get :show

        expect(response).to redirect_to(idv_doc_auth_url)
      end
    end

    context 'hybrid_handoff already visited' do
      it 'redirects to document_capture in standard flow' do
        subject.user_session['idv/doc_auth'][:flow_path] = 'standard'

        get :show

        expect(response).to redirect_to(idv_document_capture_url)
      end

      it 'redirects to link_sent in hybrid flow' do
        subject.user_session['idv/doc_auth'][:flow_path] = 'hybrid'

        get :show

        expect(response).to redirect_to(idv_link_sent_url)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth upload submitted' }

    context 'hybrid flow' do
      let(:analytics_args) do
        { success: true,
          errors: { message: nil },
          destination: :link_sent,
          flow_path: 'hybrid',
          step: 'upload',
          analytics_id: 'Doc Auth',
          irs_reproofing: false,
          telephony_response: { errors: {},
                                message_id: 'fake-message-id',
                                request_id: 'fake-message-request-id',
                                success: true } }
      end

      it 'sends analytics_submitted event for hybrid' do
        put :update, params: { doc_auth: { phone: '202-555-5555' } }

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end

    context 'desktop flow' do
      let(:analytics_args) do
        { success: true,
          errors: {},
          destination: :document_capture,
          flow_path: 'standard',
          step: 'upload',
          analytics_id: 'Doc Auth',
          irs_reproofing: false,
          skip_upload_step: false }
      end

      it 'sends analytics_submitted event for desktop' do
        put :update, params: { type: 'desktop' }

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end
  end
end
