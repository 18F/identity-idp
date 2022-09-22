module Proofing
  module LexisNexis
    class ResultWithException
      attr_reader :exception, :vendor_name

      def initialize(exception, vendor_name:)
        @exception = exception
        @vendor_name = vendor_name
      end

      def success?
        false
      end

      def errors
        {}
      end

      def timed_out?
        exception.is_a?(Proofing::TimeoutError)
      end

      def to_h
        {
          success: success?,
          errors: errors,
          exception: exception,
          timed_out: timed_out?,
          vendor_name: vendor_name,
        }
      end
    end
  end
end
