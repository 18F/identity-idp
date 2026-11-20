require 'rails_helper'

RSpec.describe Idv::Incode::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::INCODE }
  let(:vendor_switching_enabled) { true }
  let(:incode_enabled) { true }
  let(:incode_api_key) { 'test-api-key' }
  let(:incode_api_url) { 'https://demo-api.incodesmile.com' }
  let(:incode_sdk_url) { 'https://sdk.incodesmile.com/incode-web-sdk.min.js' }
  let(:incode_flow_id) { 'test-flow-id' }
  let(:user) { create(:user) }
  let(:doc_auth_success) { true }
  let(:facial_match_required) { false }
  let(:flow_path) { 'standard' }
  let(:document_type_requested) { Idp::Constants::DocumentTypes::STATE_ID_CARD }
  let(:document_type_received) { document_type_requested }
  let(:issuer) { 'standard-issuer' }

  let(:document_capture_session) do
    create(
      :document_capture_session,
      user:,
      requested_at: Time.zone.now,
      doc_auth_vendor: idv_vendor,
      document_type_requested:,
      issuer:,
    )
  end
  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  let(:stored_result) do
    DocumentCaptureSessionResult.new(
      id: SecureRandom.uuid,
      success: doc_auth_success,
      doc_auth_success: doc_auth_success,
      selfie_status: :none,
      pii: { first_name: 'Testy', last_name: 'Testerson', document_type_received: },
      attention_with_barcode: false,
      aamva_status: doc_auth_success ? :passed : :not_processed,
    )
  end

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    subject.idv_session.flow_path = flow_path
    subject.idv_session.skip_hybrid_handoff = true
    subject.idv_session.document_capture_session_uuid = document_capture_session_uuid

    acr_values = facial_match_required ?
      Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR :
      Saml::Idp::Constants::IAL_VERIFIED_ACR
    resolved_authn_context = Component::Parser.new(acr_values:).parse
    allow(controller).to receive(:resolved_authn_context_result)
      .and_return(resolved_authn_context)

    allow(IdentityConfig.store).to receive_messages(
      incode_enabled:,
      incode_api_key:,
      incode_api_url:,
      incode_sdk_url:,
      incode_flow_id:,
      doc_auth_vendor: idv_vendor,
      doc_auth_vendor_default: idv_vendor,
      doc_auth_vendor_switching_enabled: vendor_switching_enabled,
      doc_auth_selfie_vendor_default: idv_vendor,
      doc_auth_selfie_vendor_switching_enabled: vendor_switching_enabled,
    )

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)
    allow(subject).to receive(:stored_result).and_return(stored_result)

    stub_analytics
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(described_class.step_info).to be_valid
    end

    describe '#undo_step' do
      let(:idv_session) do
        Idv::Session.new(
          user_session: {},
          current_user: user,
          service_provider: nil,
        ).tap do |session|
          session.pii_from_doc = { name: 'Test' }
          session.had_barcode_attention_error = true
          session.had_barcode_read_failure = false
          session.selfie_check_performed = true
          session.source_check_vendor = 'aamva'
          session.aamva_verified_attributes = [:first_name]
        end
      end

      it 'resets relevant fields on idv_session to nil' do
        described_class.step_info.undo_step.call(idv_session:, user:)
        aggregate_failures do
          expect(idv_session.pii_from_doc).to be_nil
          expect(idv_session.had_barcode_attention_error).to be_nil
          expect(idv_session.had_barcode_read_failure).to be_nil
          expect(idv_session.selfie_check_performed).to be_nil
          expect(idv_session.source_check_vendor).to be_nil
          expect(idv_session.aamva_verified_attributes).to be_nil
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
  end

  describe '#show' do
    context 'when incode_enabled is false' do
      let(:incode_enabled) { false }

      it 'renders not found' do
        get :show

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user has not completed choose_id_type' do
      let(:document_type_requested) { nil }

      it 'redirects to choose_id_type' do
        get :show

        expect(response).to redirect_to(idv_choose_id_type_url)
      end
    end

    context 'when doc_auth_vendor is not Incode' do
      context 'when doc_auth_vendor is LexisNexis' do
        let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

        it 'redirects to the LN/mock controller' do
          get :show

          expect(response).to redirect_to(idv_document_capture_url)
        end
      end

      context 'when doc_auth_vendor is Socure' do
        let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }

        it 'redirects to the Socure controller' do
          get :show

          expect(response).to redirect_to(idv_socure_document_capture_url)
        end
      end
    end

    it 'renders the show template with Incode session locals and logs visited event' do
      expect(subject).to receive(:render).with(
        :show,
        locals: hash_including(
          document_capture_session_uuid: document_capture_session.uuid,
          user_uuid: user.uuid,
          incode_api_key: incode_api_key,
          incode_api_url: incode_api_url,
          incode_sdk_url: incode_sdk_url,
          incode_flow_id: incode_flow_id,
          update_url: idv_incode_document_capture_update_url,
        ),
      ).and_call_original

      get :show

      expect(response).to render_template(:show)
      expect(@analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        hash_including(
          step: 'incode_document_capture',
          flow_path: 'standard',
          analytics_id: 'Doc Auth',
        ),
      )
    end
  end

  describe '#update' do
    context 'when stored result is successful' do
      it 'extracts pii, logs submitted event, and redirects to ssn' do
        get :update

        expect(response).to redirect_to(idv_ssn_url)
        expect(subject.idv_session.pii_from_doc).to be_present
        expect(@analytics).to have_logged_event(
          'IdV: doc auth document_capture submitted',
          hash_including(
            success: true,
            step: 'incode_document_capture',
            flow_path: 'standard',
          ),
        )
      end
    end

    context 'when stored result fails' do
      let(:doc_auth_success) { false }

      it 'logs failed submission event and redirects back to incode document_capture' do
        get :update

        expect(response).to redirect_to(idv_incode_document_capture_url)
        expect(@analytics).to have_logged_event(
          'IdV: doc auth document_capture submitted',
          hash_including(
            success: false,
            step: 'incode_document_capture',
            flow_path: 'standard',
          ),
        )
      end
    end
  end
end
