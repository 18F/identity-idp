module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      GOOD_RESULT = 1
      FYI_RESULT = 2

      def initialize(flow)
        @assure_id = nil
        super(flow, :doc_auth)
      end

      private

      def image
        flow_params[:image]
      end

      def assure_id
        @assure_id ||= new_assure_id
        @assure_id.instance_id = flow_session[:instance_id]
        @assure_id
      end

      def new_assure_id
        klass = simulate? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId
        klass.new
      end

      def simulate?
        Figaro.env.acuant_simulator == 'true'
      end

      def attempter
        @attempter ||= Idv::Attempter.new(current_user)
      end

      def idv_failure(result)
        attempter.increment
        type = attempter.exceeded? ? :fail : :warning
        redirect_to idv_session_failure_url(reason: type)
        result
      end

      delegate :idv_session, to: :@flow
    end
  end
end
