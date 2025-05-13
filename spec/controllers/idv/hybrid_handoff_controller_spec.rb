require 'rails_helper'

RSpec.describe Idv::HybridHandoffController do
  include FlowPolicyHelper

  let(:user) { create(:user) }

  let(:service_provider) do
    create(:service_provider, :active, :in_person_proofing_enabled)
  end
  let(:in_person_proofing) { false }
  let(:ipp_opt_in_enabled) { false }
  let(:sp_selfie_enabled) { false }
  let(:document_capture_session) { create(:document_capture_session) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }

  before do
    allow(controller).to receive(:current_sp)
      .and_return(service_provider)
    stub_sign_in(user)
    stub_up_to(:agreement, idv_session: subject.idv_session)
    stub_analytics
    allow(subject.idv_session).to receive(:service_provider).and_return(service_provider)

    resolved_authn_context_result = sp_selfie_enabled ?
                                      Vot::Parser.new(vector_of_trust: 'Pb').parse :
                                      Vot::Parser.new(vector_of_trust: 'P1').parse

    allow(subject).to receive(:resolved_authn_context_result)
      .and_return(resolved_authn_context_result)

    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { in_person_proofing }
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) {
                                     ipp_opt_in_enabled
                                   }

    subject.idv_session.document_capture_session_uuid = document_capture_session_uuid
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::HybridHandoffController.step_info).to be_valid
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
    let(:analytics_name) { 'IdV: doc auth hybrid handoff visited' }
    let(:analytics_args) do
      {
        step: 'hybrid_handoff',
        analytics_id: 'Doc Auth',
        selfie_check_required: sp_selfie_enabled,
      }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'defaults to upload disabled being false' do
      get :show

      expect(assigns(:upload_disabled)).to be false
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog upload_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.upload_view_count }.from(0).to(1),
      )
    end

    context 'agreement step is not complete' do
      before do
        subject.idv_session.idv_consent_given_at = nil
      end

      it 'redirects to idv_agreement_url' do
        get :show

        expect(response).to redirect_to(idv_agreement_url)
      end
    end

    context '@upload_disabled is true' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
        allow(subject).to receive(:ab_test_bucket).and_call_original
        allow(subject).to receive(:ab_test_bucket).with(:DOC_AUTH_MANUAL_UPLOAD_DISABLED)
          .and_return(:manual_upload_disabled)
      end

      context 'selfie check required is true' do
        let(:sp_selfie_enabled) { true }
        it 'returns true' do
          get :show

          expect(assigns(:upload_disabled)).to be true
        end
      end

      context 'doc_auth_upload_disabled? is true' do
        it 'returns true' do
          get :show

          expect(assigns(:upload_disabled)).to be true
        end
      end
    end

    context 'hybrid_handoff already visited' do
      it 'shows hybrid_handoff for standard' do
        subject.idv_session.flow_path = 'standard'

        get :show

        expect(response).to render_template :show
      end

      it 'shows hybrid_handoff for hybrid' do
        subject.idv_session.flow_path = 'hybrid'

        get :show

        expect(response).to render_template :show
      end
    end

    context 'redo document capture' do
      it 'does not redirect in standard flow' do
        subject.idv_session.flow_path = 'standard'

        get :show, params: { redo: true }

        expect(response).to render_template :show
      end

      it 'does not redirect in hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'

        get :show, params: { redo: true }

        expect(response).to render_template :show
      end

      context 'idv_session.skip_hybrid_handoff? is true' do
        before do
          subject.idv_session.skip_hybrid_handoff = true
        end
        it 'redirects to document_capture' do
          subject.idv_session.flow_path = 'standard'
          get :show, params: { redo: true }

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      it 'adds redo_document_capture to analytics' do
        get :show, params: { redo: true }

        analytics_args[:redo_document_capture] = true
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      context 'user has already completed verify info' do
        before do
          stub_up_to(:verify_info, idv_session: subject.idv_session)
        end

        it 'does set redo_document_capture to true in idv_session' do
          get :show, params: { redo: true }

          expect(subject.idv_session.redo_document_capture).to be_truthy
        end

        it 'does add redo_document_capture to analytics' do
          get :show, params: { redo: true }

          expect(@analytics).to have_logged_event(analytics_name)
        end

        it 'renders show' do
          get :show, params: { redo: true }

          expect(response).to render_template :show
        end
      end
    end

    context 'hybrid flow is not available' do
      before do
        allow(FeatureManagement).to receive(:idv_allow_hybrid_flow?).and_return(false)
      end

      it 'redirects the user straight to document capture' do
        get :show
        expect(response).to redirect_to(idv_document_capture_url)
      end
      it 'does not set idv_session.skip_hybrid_handoff' do
        expect do
          get :show
        end.not_to change {
          subject.idv_session.skip_hybrid_handoff?
        }.from(false)
      end
    end

    context 'opt in ipp is enabled' do
      let(:in_person_proofing) { true }
      let(:ipp_opt_in_enabled) { true }
      before do
        stub_up_to(:how_to_verify, idv_session: subject.idv_session)
        subject.idv_session.service_provider.in_person_proofing_enabled = true
      end

      context 'opt in selection is nil' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
            .and_return(false)
          subject.idv_session.skip_doc_auth_from_how_to_verify = nil
        end

        it 'redirects to how to verify' do
          get :show

          expect(response).not_to render_template :show
          expect(response).to redirect_to(idv_how_to_verify_url)
        end
      end

      context 'opted in to hybrid flow' do
        it 'renders the show template' do
          get :show

          expect(response).to render_template :show
        end
      end

      context 'opted in to ipp flow' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
            .and_return(false)
          subject.idv_session.skip_doc_auth_from_how_to_verify = true
          subject.idv_session.skip_hybrid_handoff = true
        end

        it 'redirects to the how to verify page' do
          get :show

          expect(response).to redirect_to(idv_how_to_verify_url)
        end
      end

      context 'opt in ipp is not available on service provider' do
        before do
          subject.idv_session.service_provider.in_person_proofing_enabled = false
          subject.idv_session.skip_doc_auth_from_how_to_verify = nil
        end

        it 'renders the show template' do
          get :show

          expect(response).to render_template :show
        end
      end
    end

    context 'with selfie enabled system wide' do
      describe 'when selfie is enabled for sp' do
        let(:sp_selfie_enabled) { true }

        it 'pass on correct flags and states and logs correct info' do
          get :show
          expect(response).to render_template :show
          expect(@analytics).to have_logged_event(analytics_name, analytics_args)
          expect(subject.idv_session.selfie_check_required).to eq(true)
        end
      end

      describe 'when selfie is disabled for sp' do
        let(:sp_selfie_enabled) { false }

        it 'pass on correct flags and states and logs correct info' do
          get :show
          expect(response).to render_template :show
          expect(subject.idv_session.selfie_check_required).to eq(false)
          expect(@analytics).to have_logged_event(analytics_name, analytics_args)
        end
      end
    end
  end

  describe '#update' do
    let(:analytics_name) { 'IdV: doc auth hybrid handoff submitted' }

    context 'hybrid flow' do
      let(:analytics_args) do
        {
          success: true,
          errors: { message: nil },
          destination: :link_sent,
          flow_path: 'hybrid',
          step: 'hybrid_handoff',
          analytics_id: 'Doc Auth',
          selfie_check_required: sp_selfie_enabled,
          telephony_response: {
            errors: {},
            message_id: 'fake-message-id',
            request_id: 'fake-message-request-id',
            success: true,
          },
        }
      end

      let(:params) do
        {
          type: 'mobile',
          doc_auth: { phone: '202-555-5555' },
        }
      end

      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)

        put :update, params: params
      end

      it 'sends analytics_submitted event for hybrid' do
        put :update, params: params

        expect(subject.idv_session.phone_for_mobile_flow).to eq('+1 202-555-5555')
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'sends a doc auth link' do
        expect(Telephony).to receive(:send_doc_auth_link).with(
          hash_including(
            link: a_string_including(document_capture_session_uuid),
          ),
        ).and_call_original

        put :update, params: params
      end
    end

    context 'desktop flow' do
      let(:analytics_args) do
        {
          success: true,
          destination: :document_capture,
          flow_path: 'standard',
          step: 'hybrid_handoff',
          analytics_id: 'Doc Auth',
          selfie_check_required: sp_selfie_enabled,
        }
      end

      let(:params) do
        {
          type: 'desktop',
        }
      end

      it 'sends analytics_submitted event for desktop' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      context 'passports are not enabled' do
        before do
          allow(subject.idv_session).to receive(:passport_allowed).and_return(false)
        end
        it 'redirects to choose id type url' do
          put :update, params: params

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      context 'passports are enabled' do
        before do
          allow(subject.idv_session).to receive(:passport_allowed).and_return(true)
        end
        it 'redirects to choose id type url' do
          put :update, params: params

          expect(response).to redirect_to(idv_choose_id_type_url)
        end
      end
    end
  end
end
