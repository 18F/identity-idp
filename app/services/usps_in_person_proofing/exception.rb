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
  end
end
