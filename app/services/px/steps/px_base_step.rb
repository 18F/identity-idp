module Px
  module Steps
    class PxBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :px)
      end
    end
  end
end
