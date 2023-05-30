module JobHelpers
  module UspsProofingResultsJob
    module AnalyticsHelper
      def analytics(user: AnonymousUser.new)
        Analytics.new(user: user, request: nil, session: {}, sp: nil)
      end

      def analytics_ipp_job_exception(user: AnonymousUser.new, payload: {})
        analytics(user).idv_in_person_usps_proofing_results_job_exception(**payload)
      end

      def analytics_ipp_job_enrollment_updated(user: AnonymousUser.new, payload: {})
        analytics(user).idv_in_person_usps_proofing_results_job_enrollment_updated(**payload)
      end

      def analytics_ipp_job_email_initiated(user: AnonymousUser.new, payload: {})
        analytics(user).idv_in_person_usps_proofing_results_job_email_initiated(**payload)
      end

      def analytics_ipp_job_enrollment_incomplete(user: AnonymousUser.new, payload: {})
        analytics(user).idv_in_person_usps_proofing_results_job_enrollment_incomplete(**payload)
      end

      def analytics_ipp_job_deadline_passed_email_exception(user: AnonymousUser.new, payload: {})
        analytics(user).
          idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(**payload)
      end

      def analytics_ipp_job_deadline_passed_email_initiated(user: AnonymousUser.new, payload: {})
        analytics(user).
          idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(**payload)
      end

      def analytics_ipp_job_unexpected_response(user: AnonymousUser.new, payload: {})
        analytics(user).idv_in_person_usps_proofing_results_job_unexpected_response(**payload)
      end

      def email_analytics_attributes(enrollment)
        {
          enrollment_code: enrollment.enrollment_code,
          timestamp: Time.zone.now,
          service_provider: enrollment.issuer,
          wait_until: mail_delivery_params(enrollment.proofed_at)[:wait_until],
        }
      end

      def enrollment_analytics_attributes(enrollment, complete:)
        {
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
          minutes_since_last_status_check: enrollment.minutes_since_last_status_check,
          minutes_since_last_status_check_completed:
            enrollment.minutes_since_last_status_check_completed,
          minutes_since_last_status_update: enrollment.minutes_since_last_status_update,
          minutes_since_established: enrollment.minutes_since_established,
          minutes_to_completion: complete ? enrollment.minutes_since_established : nil,
          issuer: enrollment.issuer,
        }
      end

      def response_analytics_attributes(response)
        return { response_present: false } unless response.present?

        {
          fraud_suspected: response['fraudSuspected'],
          primary_id_type: response['primaryIdType'],
          secondary_id_type: response['secondaryIdType'],
          failure_reason: response['failureReason'],
          transaction_end_date_time: parse_usps_timestamp(response['transactionEndDateTime']),
          transaction_start_date_time: parse_usps_timestamp(response['transactionStartDateTime']),
          status: response['status'],
          assurance_level: response['assuranceLevel'],
          proofing_post_office: response['proofingPostOffice'],
          proofing_city: response['proofingCity'],
          proofing_state: response['proofingState'],
          scan_count: response['scanCount'],
          response_message: response['responseMessage'],
          response_present: true,
        }
      end
    end
  end
end
