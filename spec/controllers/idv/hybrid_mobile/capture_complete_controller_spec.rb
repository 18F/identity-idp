require 'rails_helper'

RSpec.describe Idv::HybridMobile::CaptureCompleteController do
  let(:user) { create(:user) }

  let!(:document_capture_session) do
    DocumentCaptureSession.create!(
      user: user,
      requested_at: Time.zone.now,
    )
  end

  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:confirm_document_capture_session_complete).
      and_return(true)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth capture_complete visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
        irs_reproofing: false,
        step: 'capture_complete',
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

    it 'updates DocAuthLog capture_complete_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.capture_complete_view_count }.from(0).to(1),
      )
    end
  end
end
