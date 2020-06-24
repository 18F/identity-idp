module Idv
  module Acuant
    class FakeAssureId
      FACEMATCH_DATA = { IsMatch: true }.freeze

      attr_accessor :instance_id

      def initialize
        @instance_id = '3899aab2-1da7-4e64-8c31-238f279663fc'
      end

      def face_image
        [true, 'foo']
      end

      def facematch(_body)
        [true, FACEMATCH_DATA.to_json]
      end
    end
  end
end
