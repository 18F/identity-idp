module Proofing
  module Aamva
    class Result
      attr_reader :verification_response

      delegate(
        :success?,
        to: :verification_response,
      )

      def initialize(verification_response)
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
    end
  end
end
