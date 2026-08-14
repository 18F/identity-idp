# frozen_string_literal: true

module UspsInPersonProofing
  module Exception
    class RequestEnrollException < StandardError
      attr_reader :enrollment_id, :exception_class

      def initialize(message, exception, enrollment_id)
        @enrollment_id = enrollment_id
        @exception_class = exception.class.to_s
        super(message)
      end
    end

    class InvalidResponseError < StandardError
      def initialize(endpoint_name)
        super("#{endpoint_name}: responded with an invalid response")
      end
    end

    class EnrollmentNotPendingError < StandardError
      attr_reader :enrollment_id

      def initialize(enrollment_id)
        @enrollment_id = enrollment_id
        super(
          "InPersonEnrollment #{enrollment_id} did not reach pending status after scheduling ",
        )
      end
    end
  end
end
