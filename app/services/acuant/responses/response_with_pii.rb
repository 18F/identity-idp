module Acuant
  module Responses
    class ResponseWithPii < Acuant::Response
      attr_reader :result_code

      def initialize(acuant_response:, pii:, result_code:)
        super(
          success: acuant_response.success?,
          errors: acuant_response.errors,
          exception: acuant_response.exception,
          extra: acuant_response.extra,
        )
        @pii = pii
        @result_code = result_code
      end

      def pii_from_doc
        @pii
      end
    end
  end
end
