# frozen_string_literal: true

module Idv
  module Incode
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include DocumentCaptureConcern
      include StepIndicatorConcern
      include RenderConditionConcern
      include DocAuthVendorConcern

      check_or_render_not_found -> { IdentityConfig.store.incode_enabled }

      before_action :confirm_not_rate_limited, except: :update
      before_action :confirm_step_allowed
      before_action :update_doc_auth_vendor, only: :show
      before_action :override_csp_to_allow_incode, only: :show
      before_action -> do
        redirect_to_correct_vendor(Idp::Constants::Vendors::INCODE, in_hybrid_mobile: false)
      end, only: :show

      def show
        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('incode_document_capture', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        clear_future_steps!
        idv_session.redo_document_capture = nil # done with this redo
        # Not used in standard flow, here for data consistency with hybrid flow.
        document_capture_session.confirm_ocr

        result = handle_stored_result
        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('incode_document_capture', :update, true)

        if result.success?
          redirect_to idv_ssn_url
        else
          redirect_to idv_incode_document_capture_url
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :incode_document_capture,
          controller: self,
          next_steps: [:ssn, :ipp_state_id, :ipp_choose_id_type],
          preconditions: ->(idv_session:, user:) do
            idv_session.standard_flow_document_capture_eligible? &&
              Idv::DocumentCaptureController.ensure_choose_id_type_completed(
                idv_session: idv_session,
                user: user,
              )
          end,
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.invalidate_in_person_pii_from_user!
            idv_session.had_barcode_attention_error = nil
            idv_session.had_barcode_read_failure = nil
            idv_session.selfie_check_performed = nil
            idv_session.source_check_vendor = nil
            idv_session.aamva_verified_attributes = nil
          end,
        )
      end

      private

      def extra_view_variables
        {
          document_capture_session_uuid: document_capture_session_uuid,
          user_uuid: current_user.uuid,
          incode_api_key: IdentityConfig.store.incode_api_key,
          incode_api_url: IdentityConfig.store.incode_api_url,
          incode_sdk_url: IdentityConfig.store.incode_sdk_url,
          incode_flow_id: IdentityConfig.store.incode_flow_id,
          update_url: idv_incode_document_capture_update_url,
        }
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'incode_document_capture',
          analytics_id: 'Doc Auth',
          redo_document_capture: idv_session.redo_document_capture,
          skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
          liveness_checking_required: resolved_authn_context_result.facial_match?,
          selfie_check_required: resolved_authn_context_result.facial_match?,
          pii_like_keypaths: [[:pii]],
        }.merge(ab_test_analytics_buckets)
      end

      INCODE_CSP_CONNECT_SOURCES = %w[
        https://*.cloudfront.net
        https://*.incode.com
        https://*.incodesmile.com
        https://api.ipify.org
        https://cdn.i18nexus.com
        https://featureassets.org
        https://prodregistryv2.org
      ].freeze

      INCODE_CSP_SCRIPT_SOURCES = %w[
        https://*.cloudfront.net
        https://static.opentok.com
      ].freeze

      def override_csp_to_allow_incode
        policy = current_content_security_policy
        request.content_security_policy_nonce_directives =
          request.content_security_policy_nonce_directives.without('style-src')
        api_origin = extract_origin(IdentityConfig.store.incode_api_url)
        sdk_origin = extract_origin(IdentityConfig.store.incode_sdk_url)
        policy.connect_src(
          *[policy.connect_src, api_origin, sdk_origin, INCODE_CSP_CONNECT_SOURCES]
            .flatten.compact.uniq,
        )
        policy.script_src(
          *[policy.script_src, sdk_origin, INCODE_CSP_SCRIPT_SOURCES, :unsafe_eval]
            .flatten.compact.uniq,
        )
        policy.style_src(*[policy.style_src, :unsafe_inline].flatten.compact.uniq)
        policy.img_src(
          *[policy.img_src, 'blob:', 'data:', sdk_origin, 'https://*.cloudfront.net']
            .flatten.compact.uniq,
        )
        policy.media_src(*[policy.media_src, 'blob:', 'mediastream:'].flatten.compact.uniq)
        policy.worker_src(*[policy.worker_src, :self, 'blob:'].flatten.compact.uniq)
        request.content_security_policy = policy
      end

      def extract_origin(url)
        return nil if url.blank?

        uri = URI.parse(url)
        return nil if uri.scheme.blank? || uri.host.blank?

        "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port != uri.default_port}"
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
