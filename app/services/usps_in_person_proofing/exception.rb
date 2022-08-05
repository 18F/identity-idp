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
  end
end
