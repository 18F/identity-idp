require 'rails_helper'

RSpec.describe Idv::DocumentCaptureController, allowed_extra_analytics: [:*] do
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

  # selfie related test flags
  let(:doc_auth_selfie_capture_enabled) { false }
  let(:sp_selfie_enabled) { false }
  let(:flow_path) { 'standard' }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    stub_analytics
    subject.idv_session.document_capture_session_uuid = document_capture_session_uuid
    allow(controller.decorated_sp_session).to receive(:biometric_comparison_required?).
      and_return(doc_auth_selfie_capture_enabled && sp_selfie_enabled)
    subject.idv_session.flow_path = flow_path
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::DocumentCaptureController.step_info).to be_valid
    end
    context 'when selfie feature is enabled system wide' do
      let(:doc_auth_selfie_capture_enabled) { true }
      describe 'with sp selfie disabled' do
        let(:sp_selfie_enabled) { false }
        it 'does not satisfy precondition' do
          expect(Idv::DocumentCaptureController.step_info.preconditions.is_a?(Proc))
          expect(subject).to receive(:render).
            with(:show, locals: an_instance_of(Hash)).and_call_original
          get :show
          expect(response).to render_template :show
        end
      end
      describe 'with sp selfie enabled' do
        let(:sp_selfie_enabled) { true }
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).
            and_return(false)
        end
        it 'does satisfy precondition' do
          expect(Idv::DocumentCaptureController.step_info.preconditions.is_a?(Proc))
          expect(subject).not_to receive(:render).with(:show, locals: an_instance_of(Hash))
          get :show
          expect(response).to redirect_to(idv_hybrid_handoff_path)
        end
      end
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
        liveness_checking_required: false,
        selfie_check_required: sp_selfie_enabled && doc_auth_selfie_capture_enabled,
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      expect(subject).to receive(:render).with(
        :show,
        locals: hash_including(
          document_capture_session_uuid: document_capture_session_uuid,
          doc_auth_selfie_capture: false,
        ),
      ).and_call_original

      get :show

      expect(response).to render_template :show
    end

    context 'when a selfie is requested' do
      let(:doc_auth_selfie_capture_enabled) { true }
      let(:sp_selfie_enabled) { true }
      let(:desktop_selfie_enabled) { false }
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).
          and_return(desktop_selfie_enabled)
      end
      describe 'when desktop selfie disabled' do
        let(:desktop_selfie_enabled) { false }
        it 'redirect back to handoff page' do
          expect(subject).not_to receive(:render).with(
            :show,
            locals: hash_including(
              document_capture_session_uuid: document_capture_session_uuid,
              doc_auth_selfie_capture: true,
            ),
          ).and_call_original

          get :show

          expect(response).to redirect_to(idv_hybrid_handoff_path)
        end
      end

      describe 'when desktop selfie enabled' do
        let(:desktop_selfie_enabled) { true }
        it 'allows capture' do
          expect(subject).to receive(:render).with(
            :show,
            locals: hash_including(
              document_capture_session_uuid: document_capture_session_uuid,
              doc_auth_selfie_capture: true,
            ),
          ).and_call_original

          get :show
          expect(response).to render_template :show
        end
      end
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

    context 'opt in ipp is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
        allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
        allow(IdentityConfig.store).to receive(:in_person_doc_auth_button_enabled).and_return(true)
      end

      it 'renders show when flow path is standard' do
        stub_up_to(:how_to_verify, idv_session: subject.idv_session)

        get :show

        expect(response).to render_template :show
      end

      it 'redirects to hybrid handoff url when flow path is undefined' do
        subject.idv_session.flow_path = nil

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end

      it 'redirects to hybrid handoff url when flow path is false' do
        subject.idv_session.flow_path = false

        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end

      it 'renders show when accessed from handoff' do
        allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
        allow(IdentityConfig.store).to receive(:in_person_doc_auth_button_enabled).and_return(true)
        get :show, params: { step: 'hybrid_handoff' }
        expect(response).to render_template :show
        expect(subject.idv_session.skip_doc_auth_from_handoff).to eq(true)
      end
    end

    context 'ipp disabled for sp' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
        allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).with(anything).and_return(false)
        allow(subject.decorated_sp_session).to receive(:biometric_comparison_required?).and_return(true)
      end
      it 'redirect back when accessed from handoff' do
        subject.idv_session.skip_hybrid_handoff = nil
        get :show, params: { step: 'hybrid_handoff' }
        expect(response).to redirect_to(idv_hybrid_handoff_url)
        expect(subject.idv_session.skip_doc_auth_from_handoff).to_not eq(true)
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
        liveness_checking_required: false,
        selfie_check_required: sp_selfie_enabled && doc_auth_selfie_capture_enabled,
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

    context 'selfie checks' do
      before do
        expect(controller).to receive(:selfie_requirement_met?).
          and_return(performed_if_needed)
        allow(result).to receive(:success?).and_return(true)
        allow(subject).to receive(:stored_result).and_return(result)
        allow(subject).to receive(:extract_pii_from_doc)
      end

      context 'not performed' do
        let(:performed_if_needed) { false }

        it 'stays on document capture' do
          put :update
          expect(response).to redirect_to idv_document_capture_url
        end
      end

      context 'performed' do
        let(:performed_if_needed) { true }

        it 'redirects to ssn' do
          put :update
          expect(response).to redirect_to idv_ssn_url
        end
      end
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
