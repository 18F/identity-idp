# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class ErrorsController < ApplicationController
        include DocumentCaptureConcern
        include HybridMobileConcern
        include AvailabilityConcern
        include StepIndicatorConcern
        include SocureErrorsConcern

        def show
          error_code = error_params[:error_code]
          if error_code.nil?
            error_code = error_code_for(handle_stored_result)
          end
          track_event(error_code: error_code)
          @presenter = socure_errors_presenter(error_code)
        end

        def self.step_info
          Idv::StepInfo.new(
            key: :hybrid_socure_errors,
            controller: self,
            action: :show,
            next_steps: [FlowPolicy::FINAL],
            preconditions: ->(idv_session:, user:) do
              true
            end,
            undo_step: ->(idv_session:, user:) {},
          )
        end

        private

        def error_params
          params.permit(:error_code)
        end

        def rate_limiter
          RateLimiter.new(user: document_capture_session&.user, rate_limit_type: :idv_doc_auth)
        end

        def remaining_submit_attempts
          @remaining_submit_attempts ||= rate_limiter.remaining_count
        end

        def track_event(error_code:)
          attributes = {
            error_code:,
            remaining_submit_attempts:,
            pii_like_keypaths: [[:pii]],
          }

          analytics.idv_doc_auth_socure_error_visited(**attributes)
        end

        def socure_errors_presenter(error_code)
          SocureErrorPresenter.new(
            error_code:,
            remaining_attempts: remaining_submit_attempts,
            sp_name: service_provider&.friendly_name || APP_NAME,
            issuer: service_provider&.issuer,
            flow_path: :hybrid,
          )
        end

        def service_provider
          @service_provider ||= ServiceProvider.find_by(issuer: document_capture_session&.issuer)
        end
      end
    end
  end
end
