module DocAuth
  module Mock
    module Responses
      class CreateDocumentResponse < DocAuth::Response
        attr_reader :instance_id

        def initialize(instance_id:, selfie_check_performed:, success: true, errors: [], exception: nil)
          @instance_id = instance_id
          super(
            success: success,
            errors: errors,
            exception: exception,
            selfie_check_performed: selfie_check_performed,
          )
        end
      end
    end
  end
end
