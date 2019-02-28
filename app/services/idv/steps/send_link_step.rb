module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      def call
        CaptureDoc::CreateRequest.call(current_user.id)
        SmsDocAuthLinkJob.perform_now(
          phone: permit(:phone),
          link: link,
          app: app,
        )
      end

      private

      def form_submit
        Idv::PhoneForm.new(previous_params: {}, user: current_user).submit(permit(:phone))
      end

      def link
        identity&.return_to_sp_url || root_url
      end

      def app
        identity&.friendly_name || 'login.gov'
      end

      def identity
        current_user&.identities&.order('created_at DESC')&.limit(1)&.map(&:decorate)&.first
      end
    end
  end
end
