# frozen_string_literal: true

module Idv
  module Socure
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include DocumentCaptureConcern
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.socure_enabled }
      before_action :confirm_not_rate_limited
      before_action :confirm_step_allowed
      before_action :check_aamva

      # reconsider and maybe remove these when implementing the real
      # update handler
      skip_before_action :redirect_unless_idv_session_user, only: [:update]
      skip_before_action :confirm_two_factor_authenticated, only: [:update]
      skip_before_action :confirm_idv_needed, only: [:update]
      skip_before_action :confirm_not_rate_limited, only: [:update]
      skip_before_action :confirm_step_allowed, only: [:update]

      def show
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('socure_document_capture', :view, true)

        # document request
        document_request = DocAuth::Socure::Requests::DocumentRequest.new(
          document_capture_session_uuid: document_capture_session_uuid,
          redirect_url: idv_socure_document_capture_url,
          language: I18n.locale,
        )

        document_response = document_request.fetch

        @document_request = document_request
        @document_response = document_response
        @url = document_response.dig(:data, :url)

        document_capture_session = DocumentCaptureSession.find_by(
          uuid: document_capture_session_uuid,
        )

        document_capture_session.socure_docv_transaction_token = document_response.dig(
          :data,
          :docvTransactionToken,
        )
        document_capture_session.save

        # useful for analytics
        @msg = document_response[:msg]
        @reference_id = document_response[:referenceId]
      end

      def update
        render plain: 'stub to ensure Socure callback exists and the route works'
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :socure_document_capture,
          controller: self,
          next_steps: [:ssn, :ipp_ssn],
          preconditions: ->(idv_session:, user:) {
                           idv_session.flow_path == 'standard' && (
                            # mobile
                            idv_session.skip_doc_auth_from_handoff ||
                            idv_session.skip_hybrid_handoff ||
                              idv_session.skip_doc_auth ||
                              idv_session.skip_doc_auth_from_how_to_verify ||
                              !idv_session.selfie_check_required ||
                              idv_session.desktop_selfie_test_mode_enabled?
                          )
                         },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
      end

      def state_id_proofer
        @state_id_proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::StateIdMockClient.new
          else
            Proofing::Aamva::Proofer.new(
              auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
              auth_url: IdentityConfig.store.aamva_auth_url,
              cert_enabled: IdentityConfig.store.aamva_cert_enabled,
              private_key: IdentityConfig.store.aamva_private_key,
              public_key: IdentityConfig.store.aamva_public_key,
              verification_request_timeout: IdentityConfig.store.aamva_verification_request_timeout,
              verification_url: IdentityConfig.store.aamva_verification_url,
            )
          end
      end

      def applicant_pii_with_state_id_address
        applicant_pii
      end

      def should_proof_state_id_with_aamva?
        aamva_supports_state_id_jurisdiction?
      end

      def aamva_supports_state_id_jurisdiction?
        state_id_jurisdiction = applicant_pii[:state_id_jurisdiction]
        IdentityConfig.store.aamva_supported_jurisdictions.include?(state_id_jurisdiction)
      end

      def state_id_result
        timer = JobHelpers::Timer.new
        timer.time('state_id') do
          state_id_proofer.proof(applicant_pii_with_state_id_address)
        end.tap do |result|
          add_sp_cost(:aamva, result.transaction_id) if result.exception.blank?
        end
      end

      def applicant_pii
        idv_session.pii_from_doc.to_h
      end

      def add_sp_cost(token, transaction_id)
        Db::SpCost::AddSpCost.call(current_sp, token, transaction_id: transaction_id)
      end

      def aamva_check_met?
        return state_id_result.success? if should_proof_state_id_with_aamva?

        true
      end

      def check_aamva
        idv_session.pii_from_doc = Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
        if aamva_check_met?
          # idv_session.aamva_passed = true
          redirect_to idv_ssn_url
        else
          redirect_to idv_socure_document_capture_url
        end
      end
    end
  end
end
