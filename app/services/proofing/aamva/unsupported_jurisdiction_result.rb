module Proofing
  module Aamva
    class UnsupportedJurisdictionResult
      def client
        Proofing::Aamva::Proofer.to_s
      end

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
          timed_out: timed_out?,
          vendor_name: 'UnsupportedJurisdiction',
          transaction_id: transaction_id,
        }
      end
    end
  end
end
