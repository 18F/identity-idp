module Idv
  module Steps
    class DocSuccessStep < DocAuthBaseStep
      def call
        step_successful
      end

      private

      def step_successful
        save_doc_auth
        flow_session[:image_verification_data] = {}
      end

      def save_doc_auth
        doc_auth.license_confirmed_at = Time.zone.now
        doc_auth.save
      end

      def doc_auth
        @doc_auth ||= ::DocAuth.find_or_create_by(user_id: current_user.id)
      end
    end
  end
end
