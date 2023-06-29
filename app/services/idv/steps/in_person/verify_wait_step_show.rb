module Idv
  module Steps
    module InPerson
      class VerifyWaitStepShow < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_optional_step_event
          :idv_doc_auth_optional_verify_wait_submitted
        end

        def call
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end

        private

        def exception_url
          idv_session_errors_exception_url(flow: :in_person)
        end

        def warning_url
          idv_session_errors_warning_url(flow: :in_person)
        end

        def pii
          flow_session[:pii_from_user]
        end

        def delete_pii
          flow_session.delete(:pii_from_user)
        end
      end
    end
  end
end
