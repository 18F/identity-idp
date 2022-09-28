module Proofing
  module Aamva
    class Result
      attr_reader :verification_response

      def initialize(verification_response)
        @verification_response = verification_response
      end
    end
  end
end
