# frozen_string_literal: true

module Idv
  module Socure
    class SocureErrorsController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include Idv::AbTestAnalyticsConcern

      before_action :confirm_step_allowed
      before_action :set_in_person_available

      def timeout
        @remaining_submit_attempts = rate_limiter.remaining_count
        track_event(type: :timeout)
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :socure_errors,
          controller: self,
          action: :timeout,
          next_steps: [FlowPolicy::FINAL],
          preconditions: ->(idv_session:, user:) do
            idv_session.socure_docv_wait_polling_started_at.present?
          end,
          undo_step: ->(idv_session:, user:) {},
        )
      end

      private

      def rate_limiter
        RateLimiter.new(user: idv_session.current_user, rate_limit_type: :idv_doc_auth)
      end

      def track_event(type:)
        attributes = { type: type }.merge(ab_test_analytics_buckets)
        if type == :timeout
          attributes[:remaining_submit_attempts] = @remaining_submit_attempts
        end

        analytics.idv_doc_auth_socure_error_visited(**attributes)
      end

      def set_in_person_available
        @idv_in_person_url = in_person_enabled? ? idv_in_person_url : nil
      end

      def in_person_enabled?
        IdentityConfig.store.in_person_doc_auth_button_enabled &&
          Idv::InPersonConfig.enabled_for_issuer?(document_capture_session&.issuer)
      end
    end
  end
end
