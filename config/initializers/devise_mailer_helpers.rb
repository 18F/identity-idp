# This overrides the Devise mailer headers so that the recipient
# is determined based on whether or not an unconfirmed_email is present,
# as opposed to passing in the email as an argument to the job, which
# might expose it in some logs.
module Devise
  module Mailers
    module Helpers
      def headers_for(action, opts)
        headers = {
          subject: subject_for(action),
          to: recipient,
          template_path: template_paths,
          template_name: action,
        }.merge(opts)

        @email = headers[:to]
        headers
      end

      private

      def recipient
        resource.unconfirmed_email.presence || resource.email
      end
    end
  end
end
