module Proofing
  module Aamva
    class UnsupportedJurisdictionResult
      def errors
        {}
      end

      def exception
        nil
      end

      def success?
        true
      end

      def timed_out?
        false
      end

      def transaction_id
        ''
      end

      def to_h
        {
          errors: errors,
          exception: exception,
          success: success?,
          vendor_name: 'UnsupportedJurisdiction',
        }
      end
    end
  end
end
