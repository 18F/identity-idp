module Idv
  module Steps
    class InheritedProofingBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :inherited_proofing)
      end
    end
  end
end
