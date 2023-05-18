module InPerson
  module EnrollmentsReadyForStatusCheck
    class ErrorReporter
      # @param [String] class_name Class for which to report errors
      # @param [InPerson::EnrollmentsReadyForStatusCheck::UserAnalyticsFactory] analytics_factory
      def initialize(class_name, analytics_factory)
        @class_name = class_name
        @analytics_factory = analytics_factory
      end

      # Reports an error. A non-StandardError will be converted to
      # a RuntimeError before being reported.
      # @param [#to_s,StandardError] error
      def report_error(error, **extra)
        error = RuntimeError.new("#{@class_name}: #{error}") unless error.is_a?(StandardError)
        analytics.idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error(
          exception_class: error.class,
          exception_message: error.message,
          **extra,
        )
        NewRelic::Agent.notice_error(error)
      end

      private

      attr_reader :analytics_factory
      delegate :analytics, to: :analytics_factory
    end
  end
end
