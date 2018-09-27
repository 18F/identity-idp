module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      def call
        flow_session[:ssn] = flow_params[:ssn]
      end

      private

      def form_submit
        Idv::SsnForm.new(current_user).submit(permit(:ssn))
      end
    end
  end
end
