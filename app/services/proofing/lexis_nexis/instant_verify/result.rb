module Proofing
  module LexisNexis
    module InstantVerify
      class Result
        attr_reader :verification_response

        delegate(
          :reference,
          :verification_status,
          :verification_errors,
          to: :verification_response,
        )

        def initialize(verification_response)
          @verification_response = verification_response
        end

        def errors
          return @errors if defined?(@errors)

          @errors = {}
          verification_errors.each do |key, value|
            @errors[key] ||= []
            @errors[key].push(value)
          end
          @errors
        end

        def exception
          nil
        end

        def success?
          verification_response.verification_status == 'passed'
        end

        def failed_result_can_pass_with_additional_verification?
          return false unless !success?
          return false unless verification_errors.keys.sort == [:"Execute Instant Verify", :base]
          if !verification_errors[:base].match?(/total\.scoring\.model\.verification\.fail/)
            return false
          end

          true
        end

        def attributes_requiring_additional_verification
          @attributes_requiring_additional_verification ||= CheckToAttributeMapper.new(
            verification_errors[:"Execute Instant Verify"],
          ).map_failed_checks_to_attributes
        end

        def timed_out?
          false
        end

        def transaction_id
          verification_response.conversation_id
        end

        def to_h
          {
            exception: exception,
            errors: errors,
            success: success?,
            timed_out: timed_out?,
            transaction_id: transaction_id,
            vendor_name: 'lexisnexis:instant_verify',
          }
        end
      end
    end
  end
end
