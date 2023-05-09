module InPerson
  module EnrollmentsReadyForStatusCheck
    module UsesReportError
      include UsesAnalytics

      def report_error(error, **extra)
        error = StandardError.new("#{self.class.name}: #{error}") if error.is_a?(String)
        analytics.idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error(
          error:,
          **extra,
        )
        NewRelic::Agent.notice_error(err)
      end
    end
  end
end
