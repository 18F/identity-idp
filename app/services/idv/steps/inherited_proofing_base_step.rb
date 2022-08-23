module Idv
  module Steps
    class InheritedProofingBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :inherited_proofing)
      end

      delegate :idv_session, :session, :flow_path, to: :@flow
    end
  end
end
