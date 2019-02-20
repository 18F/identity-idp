module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      def call
        flow_session[:pii_from_doc][:ssn] = flow_params[:ssn]
      end

      private

      def form_submit
        Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
      end
    end
  end
end
