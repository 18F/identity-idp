module Proofing
  module LexisNexis
    module PhoneFinder
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

        def success?
          verification_response.verification_status == 'passed'
        end

        def timed_out?
          false
        end

        def transaction_id
          verification_response.conversation_id
        end
      end
    end
  end
end
