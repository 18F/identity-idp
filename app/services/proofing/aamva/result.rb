module Proofing
  module Aamva
    class Result
      attr_reader :verification_response

      delegate(
        :success?,
        to: :verification_response,
      )

      def initialize(verification_response)
        raise ArgumentError unless verification_response.instance_of? Response::VerificationResponse
        @verification_response = verification_response
      end

      def errors
        return @errors if defined? @errors

        @errors = {}
        return @errors if verification_response.success?

        verification_response.verification_results.each do |attribute, v_result|
          attribute_key = attribute.to_sym
          next if v_result == true
          @errors[attribute_key] ||= []
          @errors[attribute_key].push('UNVERIFIED') if v_result == false
          @errors[attribute_key].push('MISSING') if v_result.nil?
        end
        @errors
      end

      def transaction_id
        verification_response.transaction_locator_id
      end

      def exception
        nil
      end

      def timed_out?
        false
      end

      def vendor_name
        'aamva:state_id'
      end

      def to_h
        {
          exception: exception,
          errors: errors,
          success: success?,
          timed_out: timed_out?,
          transaction_id: transaction_id,
          vendor_name: vendor_name,
        }
      end
    end
  end
end
