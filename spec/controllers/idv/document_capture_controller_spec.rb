require 'rails_helper'

RSpec.describe Idv::DocumentCaptureController do
  include IdvHelper

  let(:flow_session) do
    { document_capture_session_uuid: 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      threatmetrix_session_id: 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0' }
  end

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
    subject.idv_session.flow_path = 'standard'
    subject.user_session['idv/doc_auth'] = flow_session
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

    it 'checks that hybrid_handoff is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_hybrid_handoff_complete,
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
        acuant_sdk_upgrade_ab_test_bucket: :default,
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

    context 'redo_document_capture' do
      it 'adds redo_document_capture to analytics' do
        flow_session[:redo_document_capture] = true

        get :show

        analytics_args[:redo_document_capture] = true
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end

    it 'updates DocAuthLog document_capture_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.document_capture_view_count }.from(0).to(1),
      )
    end

    context 'hybrid handoff step is not complete' do
      it 'redirects to hybrid handoff' do
        subject.idv_session.flow_path = nil

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end

    context 'with pii in session' do
      it 'redirects to ssn step' do
        flow_session['pii_from_doc'] = Idp::Constants::MOCK_IDV_APPLICANT
        get :show

        expect(response).to redirect_to(idv_ssn_url)
      end
    end

    it 'does not use effective user outside of analytics_user in ApplicationControler' do
      allow(subject).to receive(:analytics_user).and_return(subject.current_user)
      expect(subject).not_to receive(:effective_user)

      get :show
    end

    context 'user is rate limited' do
      it 'redirects to rate limited page' do
        user = create(:user)

        RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment_to_limited!
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
        acuant_sdk_upgrade_ab_test_bucket: :default,
      }
    end
    let(:result) { { success: true, errors: {} } }

    it 'sends analytics_submitted event' do
      allow(result).to receive(:success?).and_return(true)
      allow(subject).to receive(:handle_stored_result).and_return(result)

      put :update

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
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

    context 'user has an establishing in-person enrollment' do
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: nil) }

      it 'cancels the establishing enrollment' do
        expect(user.establishing_in_person_enrollment).to eq enrollment

        put :update

        expect(enrollment.reload.cancelled?).to eq(true)
        expect(user.reload.establishing_in_person_enrollment).to be_nil
      end
    end
  end
end
