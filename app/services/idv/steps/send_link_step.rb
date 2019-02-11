module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      def call
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
        current_user&.identities&.order('created_at DESC')&.limit(1)&.map(&:decorate)&.first&.
          return_to_sp_url || root_url
      end

      def app
        current_user&.identities&.order('created_at DESC')&.limit(1)&.map(&:decorate)&.first&.
          friendly_name || 'login.gov'
      end
    end
  end
end
