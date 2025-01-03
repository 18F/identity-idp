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
  let(:ab_test_args) { {} }

  # selfie related test flags
  let(:sp_selfie_enabled) { false }
  let(:flow_path) { 'standard' }
  let(:doc_auth_selfie_desktop_test_mode) { false }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    stub_analytics
    subject.idv_session.document_capture_session_uuid = document_capture_session_uuid

    vot = sp_selfie_enabled ? 'Pb' : 'P1'
    resolved_authn_context = Vot::Parser.new(vector_of_trust: vot).parse

    allow(controller).to receive(:resolved_authn_context_result)
      .and_return(resolved_authn_context)
    subject.idv_session.flow_path = flow_path
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)

    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(
      Idp::Constants::Vendors::LEXIS_NEXIS,
    )
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(
      Idp::Constants::Vendors::LEXIS_NEXIS,
    )

    allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
      .and_return(doc_auth_selfie_desktop_test_mode)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::DocumentCaptureController.step_info).to be_valid
    end

    context 'when selfie feature is enabled system wide' do
      describe 'with sp selfie disabled' do
        let(:sp_selfie_enabled) { false }

        it 'does not satisfy precondition' do
          expect(Idv::DocumentCaptureController.step_info.preconditions.is_a?(Proc))
          expect(subject).to receive(:render)
            .with(:show, locals: an_instance_of(Hash)).and_call_original
          get :show
          expect(response).to render_template :show
        end
      end

      describe 'with sp selfie enabled' do
        let(:sp_selfie_enabled) { true }

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

    it 'includes setup_usps_form_presenter before_action' do
      expect(subject).to have_actions(
        :before,
        :set_usps_form_presenter,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth document_capture visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        step: 'document_capture',
        liveness_checking_required: false,
        selfie_check_required: sp_selfie_enabled,
      }
    end

    let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }
    let(:vendor_switching_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(
        idv_vendor,
      )
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(
        idv_vendor,
      )
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled).and_return(
        vendor_switching_enabled,
      )
    end

    it 'has non-nil presenter' do
      get :show
      expect(assigns(:presenter)).to be_kind_of(Idv::InPerson::UspsFormPresenter)
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

    context 'when we try to use this controller but we should be using the Socure version' do
      let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

      it 'redirects to the Socure controller' do
        get :show

        expect(response).to redirect_to idv_socure_document_capture_url
      end

      context 'when redirect to correct vendor is disabled' do
        before do
          allow(IdentityConfig.store)
            .to receive(:doc_auth_disable_redirect_to_correct_vendor).and_return(true)
        end

        it 'redirects to the Socure controller' do
          get :show

          expect(response).to render_template :show
        end
      end
    end

    context 'socure is the default vendor but facial match is required' do
      let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
      let(:vot) { 'Pb' }

      before do
        resolved_authn_context = Vot::Parser.new(vector_of_trust: vot).parse
        allow(controller).to receive(:resolved_authn_context_result)
          .and_return(resolved_authn_context)
      end

      it 'does not redirect to Socure controller' do
        get :show

        expect(response).to_not redirect_to idv_socure_document_capture_url
      end
    end

    context 'when a selfie is requested' do
      let(:sp_selfie_enabled) { true }

      describe 'when desktop selfie disabled' do
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
        let(:doc_auth_selfie_desktop_test_mode) { true }
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

    context 'redo_document_capture' do
      it 'adds redo_document_capture to analytics' do
        subject.idv_session.redo_document_capture = true

        get :show

        analytics_args[:redo_document_capture] = true
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
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
      let(:sp_selfie_enabled) { true }

      before do
        allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).with(anything).and_return(false)
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
        step: 'document_capture',
        liveness_checking_required: false,
        selfie_check_required: sp_selfie_enabled,
      }
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
        expect(controller).to receive(:selfie_requirement_met?)
          .and_return(performed_if_needed)
        allow(result).to receive(:success?).and_return(true)
        allow(result).to receive(:errors).and_return(result[:errors])
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

  describe '#direct_in_person' do
    let(:analytics_name) { :idv_in_person_direct_start }
    let(:analytics_args) do
      {
        remaining_submit_attempts: 4,
        skip_hybrid_handoff: nil,
        opted_in_to_in_person_proofing: nil,
      }
    end

    it 'sends analytics event' do
      expect(@analytics).to receive(:track_event).with(analytics_name, analytics_args)

      get :direct_in_person
    end

    it 'redirects to document capture' do
      get :direct_in_person

      expect(response).to redirect_to(idv_document_capture_url(step: :idv_doc_auth))
    end
  end
end
