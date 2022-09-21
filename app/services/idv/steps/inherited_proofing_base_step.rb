module Idv
  module Steps
    class InheritedProofingBaseStep < Flow::BaseStep
      delegate :idv_session, :session, :flow_path, to: :@flow   # from doc_auth_base_step, fixes access to :idv_session

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
