require 'rails_helper'

describe Idv::DocumentCaptureController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard',
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

  let(:default_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_default }
  let(:alternate_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_alternate }

  before do
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

    it 'checks that upload step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_upload_step_complete,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth document_capture visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'document_capture',
      }
    end

    it 'renders the show template' do
      expect(subject).to receive(:render).with(
        :show,
        locals: hash_including(
          document_capture_session_uuid: flow_session[:document_capture_session_uuid],
        ),
      ).and_call_original

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
        change { doc_auth_log.reload.document_capture_view_count }.from(0).to(1),
      )
    end

    context 'upload step is not complete' do
      it 'redirects to idv_doc_auth_url' do
        flow_session.delete(:flow_path)

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

    context 'user is rate_limited' do
      it 'redirects to rate limited page' do
        user = create(:user)

        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment_to_throttled!
        allow(subject).to receive(:current_user).and_return(user)

        get :show

        expect(response).to redirect_to(idv_session_errors_throttled_url)
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth document_capture submitted' }
    let(:analytics_args) do
      {
        success: true,
        errors: {},
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'document_capture',
      }
    end

    it 'does not raise an exception when stored_result is nil' do
      allow(subject).to receive(:stored_result).and_return(nil)
      put :update
    end

    it 'updates DocAuthLog document_capture_submit_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { put :update }.to(
        change { doc_auth_log.reload.document_capture_submit_count }.from(0).to(1),
      )
    end
  end
end
