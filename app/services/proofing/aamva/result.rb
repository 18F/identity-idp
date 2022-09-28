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
        verification_response.verification_results.each do |attribute, v_result|
          next if v_result == true
          @errors[attribute.to_sym] ||= []
          @errors[attribute.to_sym].push('UNVERIFIED') if v_result == false
          @errors[attribute.to_sym].push('MISSING') if v_result.nil?
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
        # TODO
      end
    end
  end
end
