module InPerson
  module EnrollmentsReadyForStatusCheck
    module UsesReportError
      include UsesAnalytics

      # Reports an error. A non-StandardError will be converted to
      # a RuntimeError before being reported.
      # @param [#to_s,StandardError] error
      def report_error(error, **extra)
        error = RuntimeError.new("#{self.class.name}: #{error}") unless error.is_a?(StandardError)
        analytics.idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error(
          exception_class: error.class,
          exception_message: error.message,
          **extra,
        )
        NewRelic::Agent.notice_error(error)
      end
    end
  end
end
