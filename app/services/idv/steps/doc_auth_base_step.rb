module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      def initialize(context)
        @assure_id = nil
        super(context, :doc_auth)
      end

      private

      def image
        flow_params[:image]
      end

      def assure_id
        @assure_id ||= Idv::Acuant::AssureId.new
        @assure_id.instance_id = flow_session[:instance_id]
        @assure_id
      end

      delegate :idv_session, to: :@context
    end
  end
end
