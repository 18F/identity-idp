module Acuant
  module Responses
    class ResponseWithPii < Acuant::Response
      def initialize(acuant_response:, pii:, billed:)
        super(
          success: acuant_response.success?,
          errors: acuant_response.errors,
          exception: acuant_response.exception,
          extra: acuant_response.extra.merge(billed: billed),
        )
        @pii = pii
      end

      def pii_from_doc
        @pii
      end
    end
  end
end
