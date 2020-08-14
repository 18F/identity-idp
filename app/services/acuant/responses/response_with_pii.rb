module Acuant
  module Responses
    class ResponseWithPii < Acuant::Response
      def initialize(acuant_response:, pii:, result_code:)
        super(
          success: acuant_response.success?,
          errors: acuant_response.errors,
          exception: acuant_response.exception,
          extra: acuant_response.extra.merge(
            result: result_code.name,
            billed: result_code.billed?,
          ),
        )
        @pii = pii
      end

      def pii_from_doc
        @pii
      end
    end
  end
end
