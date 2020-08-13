module DocAuthMock
  module Responses
    class CreateDocumentResponse < DocAuthClient::Response
      attr_reader :instance_id

      def initialize(success: true, errors: [], exception: nil, instance_id:)
        @instance_id = instance_id
        super(
          success: success,
          errors: errors,
          exception: exception,
        )
      end
    end
  end
end
