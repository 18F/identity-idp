require 'rails_helper'

RSpec.describe Idv::DocumentCaptureController do
  include FlowPolicyHelper

  let(:document_capture_session_requested_at) { Time.zone.now }

  let!(:document_capture_session) do
    DocumentCaptureSession.create!(
      user: user,
      requested_at: document_capture_session_requested_at,
    )
  end

  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    stub_analytics
    subject.idv_session.document_capture_session_uuid = document_capture_session_uuid

    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::DocumentCaptureController.step_info).to be_valid
    end
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
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth document_capture visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        redo_document_capture: nil,
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
        step: 'document_capture',
      }.merge(ab_test_args)
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

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'redo_document_capture' do
      it 'adds redo_document_capture to analytics' do
        subject.idv_session.redo_document_capture = true

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

    context 'verify info step is complete' do
      it 'renders show' do
        stub_up_to(:verify_info, idv_session: subject.idv_session)

        get :show

        expect(response).to render_template :show
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

        expect(response).to redirect_to(idv_session_errors_rate_limited_url)
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
        redo_document_capture: nil,
        skip_hybrid_handoff: nil,
        irs_reproofing: false,
        step: 'document_capture',
      }.merge(ab_test_args)
    end
    let(:result) { { success: true, errors: {} } }

    it 'invalidates future steps' do
      subject.idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT
      expect(subject).to receive(:clear_future_steps!).and_call_original

      put :update
      expect(subject.idv_session.applicant).to be_nil
    end

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

    context 'ocr confirmation pending' do
      before do
        subject.document_capture_session.ocr_confirmation_pending = true
      end

      it 'confirms ocr' do
        put :update
        expect(subject.document_capture_session.ocr_confirmation_pending).to be_falsey
      end
    end
  end
end
