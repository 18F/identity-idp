module Idv
  module Steps
    module InPerson
      class SsnStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        include ThreatMetrixStepHelper
        include TempMaybeRedirectToVerifyInfoHelper

        def self.analytics_visited_event
          :idv_doc_auth_ssn_visited
        end

        def self.analytics_submitted_event
          :idv_doc_auth_ssn_submitted
        end

        def call
          flow_session[:pii_from_user][:ssn] = ssn

          @flow.irs_attempts_api_tracker.idv_ssn_submitted(
            ssn: ssn,
          )

          idv_session.delete('applicant')

          # maybe_redirect_to_verify_info
          # add this in its own pr for now
          # if (IdentityConfig.store.in_person_verify_info_controller_enabled)
          redirect_to idv_in_person_verify_info_url
          # end
        end

        def extra_view_variables
          {
            updating_ssn: updating_ssn?,
            **threatmetrix_view_variables,
          }
        end

        private

        def form_submit
          Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
        end

        def ssn
          flow_params[:ssn]
        end

        def updating_ssn?
          flow_session.dig(:pii_from_user, :ssn).present?
        end
      end
    end
  end
  end
