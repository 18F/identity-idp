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
          client: client,
          errors: errors,
          exception: exception,
          success: success?,
          vendor_name: 'UnsupportedJurisdiction',
        }
      end
    end
  end
end
