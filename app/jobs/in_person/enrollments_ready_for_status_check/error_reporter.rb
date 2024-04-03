# frozen_string_literal: true

module InPerson
  module EnrollmentsReadyForStatusCheck
    class ErrorReporter
      # @param [String] class_name Class for which to report errors
      # @param [Analytics] analytics
      def initialize(class_name, analytics)
        @class_name = class_name
        @analytics = analytics
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

      attr_reader :analytics
    end
  end
end
