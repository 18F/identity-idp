# frozen_string_literal: true

module Idv
  module Socure
    class ErrorsController < ApplicationController
      include DocumentCaptureConcern
      include AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include AbTestAnalyticsConcern

      before_action :confirm_step_allowed

      def show
        error_code = error_code_for(handle_stored_result)
        track_event(error_code: error_code)
        @presenter = socure_errors_presenter(error_code)
      end

      def timeout
        track_event(error_code: :timeout)
        @presenter = socure_errors_presenter(:timeout)
        render :show
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :socure_errors,
          controller: self,
          action: :timeout,
          next_steps: [FlowPolicy::FINAL],
          preconditions: ->(idv_session:, user:) do
            true
          end,
          undo_step: ->(idv_session:, user:) {},
        )
      end

      private

      def rate_limiter
        RateLimiter.new(user: idv_session.current_user, rate_limit_type: :idv_doc_auth)
      end

      def remaining_submit_attempts
        @remaining_submit_attempts ||= rate_limiter.remaining_count
      end

      def track_event(error_code:)
        attributes = { error_code: }.merge(ab_test_analytics_buckets)
        attributes[:remaining_submit_attempts] = remaining_submit_attempts

        analytics.idv_doc_auth_socure_error_visited(**attributes)
      end

      def socure_errors_presenter(error_code)
        SocureErrorPresenter.new(
          error_code:,
          remaining_attempts: remaining_submit_attempts,
          sp_name: decorated_sp_session&.sp_name || APP_NAME,
          issuer: decorated_sp_session&.sp_issuer,
          flow_path:,
        )
      end

      def error_code_for(result)
        if result.errors[:socure]
          result.errors.dig(:socure, :reason_codes).first
        elsif result.errors[:network]
          :network
        else
          # No error information available (shouldn't happen). Default
          # to :network if it does.
          :network
        end
      end
    end
  end
end
