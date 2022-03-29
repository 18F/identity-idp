module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        return mark_step_incomplete(:document_capture) if flow_session[:pii_from_doc].nil?

        flow_session[:pii_from_doc][:ssn] = flow_params[:ssn]
      end

      private

      def form_submit
        Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
      end
    end
  end
end
