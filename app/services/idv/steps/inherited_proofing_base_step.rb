module Idv
  module Steps
    class InheritedProofingBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :inherited_proofing)
      end

      private

      def sp_session
        session.fetch(:sp, {})
      end
    end
  end
end
