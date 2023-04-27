require 'rails_helper'

describe Idv::LinkSentController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'hybrid',
      :phone_for_mobile_flow => '201-555-1212',
      'Idv::Steps::UploadStep' => true }
  end

  let(:user) { create(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'checks that upload step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_upload_step_complete,
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
      }
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

    context 'upload step is not complete' do
      it 'redirects to idv_doc_auth_url' do
        flow_session['Idv::Steps::UploadStep'] = nil

        get :show

        expect(response).to redirect_to(idv_doc_auth_url)
      end
    end

    context 'with pii in session' do
      it 'redirects to ssn step' do
        flow_session['pii_from_doc'] = Idp::Constants::MOCK_IDV_APPLICANT
        get :show

        expect(response).to redirect_to(idv_ssn_url)
      end
    end
  end
end
