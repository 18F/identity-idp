module Acuant
  module Responses
    class UploadImageResponse < Acuant::Response
      def initialize
        super(success: true)
      end
    end
  end
end
