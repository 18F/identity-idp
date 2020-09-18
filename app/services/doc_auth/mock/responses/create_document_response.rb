module DocAuth
  module Mock
    module Responses
      class CreateDocumentResponse < DocAuth::Response
        attr_reader :instance_id

        def initialize(instance_id:, success: true, errors: [], exception: nil)
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
end
