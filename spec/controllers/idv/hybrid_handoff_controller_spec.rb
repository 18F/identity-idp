require 'rails_helper'

describe Idv::HybridHandoffController do
  include IdvHelper

  let(:flow_session) do
    { 'Idv::Steps::AgreementStep' => true }
  end

  let(:user) { create(:user) }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_hybrid_handoff_controller_enabled).
      and_return(true)
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
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
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth upload visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        irs_reproofing: false,
        step: 'upload',
      }
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
        flow_session['Idv::Steps::AgreementStep'] = nil

        get :show

        expect(response).to redirect_to(idv_doc_auth_url)
      end
    end
  end
end
