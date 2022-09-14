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
