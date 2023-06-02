module JobHelpers::UspsProofingResultsJob
  class AnalyticsHelper
    def initialize(enrollment)
      @enrollment = enrollment
      @user = enrollment.user
    end

    def analytics
      Analytics.new(user: @user, request: nil, session: {}, sp: nil)
    end

    def analytics_ipp_job_exception(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_exception(**payload)
    end

    def analytics_ipp_job_enrollment_updated(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_enrollment_updated(**payload)
    end

    def analytics_ipp_job_email_initiated(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_email_initiated(**payload)
    end

    def analytics_ipp_job_deadline_passed_email(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(**payload)
    end

    def analytics_ipp_job_deadline_passed_email_exception(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(**payload)
    end

    def analytics_ipp_job_deadline_passed_email_initiated(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(**payload)
    end

    def analytics_ipp_job_unexpected_response(payload: {})
      analytics.idv_in_person_usps_proofing_results_job_unexpected_response(**payload)
    end

    def enrollment_analytics_attributes(complete:)
      {
        enrollment_code: @enrollment.enrollment_code,
        enrollment_id: @enrollment.id,
        minutes_since_last_status_check: @enrollment.minutes_since_last_status_check,
        minutes_since_last_status_check_completed:
          @enrollment.minutes_since_last_status_check_completed,
        minutes_since_last_status_update: @enrollment.minutes_since_last_status_update,
        minutes_since_established: @enrollment.minutes_since_established,
        minutes_to_completion: complete ? @enrollment.minutes_since_established : nil,
        issuer: @enrollment.issuer,
      }
    end
  end
end

