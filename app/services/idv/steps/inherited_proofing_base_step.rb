module Idv
  module Steps
    class InheritedProofingBaseStep < Flow::BaseStep
      delegate :controller, :idv_session, to: :@flow

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
