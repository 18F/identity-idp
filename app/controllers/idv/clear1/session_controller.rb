# frozen_string_literal: true

module Idv
  module Clear1
    class SessionController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.idv_clear1_enabled }

      before_action :confirm_not_rate_limited, except: :update
      before_action :confirm_step_allowed

      def show
        timer = JobHelpers::Timer.new
        clear1_session = timer.time('vendor_request') do
          clear1_session_request = Proofing::Clear1::Requests::SessionRequest.new(
            user_uuid: current_user.uuid,
            redirect_url: idv_clear1_session_update_url,
          )
          clear1_session_request.fetch
        end

        if clear1_session.success?
          token = clear1_session.extra[:token]

          @clear1_endpoint = UriService.add_params(
            [IdentityConfig.store.idv_clear1_api_base_url, 'verify'].join('/'),
            { token: },
          )

          idv_session.clear1_verification_token = token
          idv_session.clear1_verification_session_id = clear1_session.extra[:id]
          idv_session.clear1_verification_state = clear1_session.extra[:state]
          document_capture_session.update!(doc_auth_vendor: Idp::Constants::Vendors::CLEAR1)
        else
          redirect_to idv_hybrid_handoff_path
        end
      end

      def update
        clear_future_steps!
        idv_session.redo_document_capture = nil # done with this redo

        # TODO: new analytics event

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('clear1_inherited_proofing', :update, true)

        result = fetch_synchronous_verification_result

        if result.success?
          idv_session.clear1_verified = true
          pii = extract_pii_from_result(result)
          # todo: validate_pii_from_result(pii)
          idv_session.applicant = pii
          redirect_to idv_enter_password_url
        else
          # todo: redirect_to clear1 failure page
          idv_session.clear1_verified = false
          redirect_to idv_clear1_session_url
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :clear1_session,
          controller: self,
          next_steps: [:enter_password],
          preconditions: ->(idv_session:, user:) {
            idv_session.flow_path == 'standard' &&
            idv_session.clear1_allowed
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.doc_auth_vendor = nil
            idv_session.source_check_vendor = nil
            idv_session.clear1_verification_token = nil
            idv_session.clear1_verification_session_id = nil
            idv_session.clear1_verification_state = nil
          end,
        )
      end

      private

      def analytics_arguments
        {
          flow_path:,
          step: 'clear1_session',
          pii_like_keypaths: [[:pii]],
        }.merge(ab_test_analytics_buckets)
      end

      def fetch_synchronous_verification_result
        # todo: make async
        timer = JobHelpers::Timer.new
        timer.time('vendor_request') do
          Proofing::Clear1::Requests::ResultRequest.new(
            verification_session_id: idv_session.clear1_verification_session_id,
          ).fetch
        end
      end

      def extract_pii_from_result(result)
        idv_session.doc_auth_vendor = document_capture_session.doc_auth_vendor
        idv_session.applicant = result.pii
      end
    end
  end
end
