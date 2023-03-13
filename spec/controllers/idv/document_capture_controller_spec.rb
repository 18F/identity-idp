require 'rails_helper'

describe Idv::DocumentCaptureController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      'pii_from_doc' => Idp::Constants::MOCK_IDV_APPLICANT.dup,
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard' }
  end

  let(:user) { create(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end

  let(:default_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_default }
  let(:alternate_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_alternate }

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :render_404_if_document_capture_controller_disabled,
      )
    end

    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  context 'when doc_auth_document_capture_controller_enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_document_capture_controller_enabled).
        and_return(true)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    describe '#show' do
      let(:analytics_name) { 'IdV: doc auth document_capture visited' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'document capture',
          step_count: 1,
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

      it 'sends correct step count to analytics' do
        get :show
        get :show
        analytics_args[:step_count] = 2

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end


    it 'updates DocAuthLog document_capture_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.document_capture_view_count }.from(0).to(1),
      )
    end
    end

    describe '#update' do
      let(:analytics_name) { 'IdV: doc auth document_capture submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'document capture',
          step_count: 1,
        }
      end

      it 'does not raise an exception when stored_result is nil' do
        allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
          and_return(false)
        allow(subject).to receive(:stored_result).and_return(nil)
        put :update
      end

      it 'sends analytics_submitted event with correct step count' do
        get :show
        put :update

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end


      it 'updates DocAuthLog document_capture_submit_count' do
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { put :update }.to(
          change { doc_auth_log.reload.document_capture_submit_count }.from(0).to(1),
        )
      end
    end
  end

  context 'when doc_auth_document_capture_controller_enabled is false' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_document_capture_controller_enabled).
        and_return(false)
    end

    it 'returns 404' do
      get :show

      expect(response.status).to eq(404)
    end
  end
end
