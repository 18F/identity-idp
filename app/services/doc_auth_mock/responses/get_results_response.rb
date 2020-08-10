module DocAuthMock
  module Responses
    class GetResultsResponse < Acuant::Response
      attr_reader :pii_from_doc

      def initialize(
        success: true,
        errors: [],
        exception: nil,
        pii_from_doc:,
        result_code: Acuant::ResultCodes::PASSED
      )
        @pii_from_doc = pii_from_doc
        super(
          success: success,
          errors: errors,
          exception: exception,
          extra: {
            billed: result_code.billed?,
            result: result_code.name,
          },
        )
      end
    end
  end
end
