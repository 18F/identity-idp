# frozen_string_literal: true

module Idv
  module Clear1
    class SessionController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include RenderConditionConcern

      check_or_render_not_found -> { clear1_enabled? }

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
          document_capture_session.update!(doc_auth_vendor: Idp::Constants::Vendors::CLEAR1)
        else
          redirect_to idv_hybrid_handoff_path
        end
      end

      def update
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :clear1_session,
          controller: self,
          next_steps: [:enter_password],
          preconditions: ->(idv_session:, user:) {
            idv_session.flow_path == 'standard' &&
            idv_session.clear1_enabled
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.doc_auth_vendor = nil
            idv_session.source_check_vendor = nil
            idv_session.clear1_verification_token = nil
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
    end
  end
end
