module DocAuthMock
  module Responses
    class GetResultsResponse < Acuant::Response
      attr_reader :pii_from_doc

      def initialize(
        success: true,
        errors: [],
        exception: nil,
        pii_from_doc:,
        billed: true
      )
        @pii_from_doc = pii_from_doc
        super(
          success: success,
          errors: errors,
          exception: exception,
          extra: { billed: billed },
        )
      end
    end
  end
end
