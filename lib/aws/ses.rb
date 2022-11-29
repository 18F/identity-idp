##
# ActionMailer delivery method for SES inspired by https://github.com/drewblas/aws-ses
#
module Aws
  module SES
    class Base
      cattr_accessor :region_pool

      def initialize(*); end

      def deliver(mail)
        response = send_raw_email(mail)
        mail.header[:ses_message_id] = response.message_id
        response
      end

      alias deliver! deliver

      private

      def send_raw_email(mail)
        if IdentityConfig.store.ses_configuration_set_name.present?
          ses_client.send_raw_email(
            raw_message: { data: mail.to_s },
            configuration_set_name: IdentityConfig.store.ses_configuration_set_name,
          )
        else
          ses_client.send_raw_email(raw_message: { data: mail.to_s })
        end
      end

      def ses_client
        @ses_client ||= Aws::SES::Client.new(ses_client_options)
      end

      def ses_client_options
        {
          # https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/timeout-duration.html
          retry_limit: 3,
          retry_backoff: ->(_context) { sleep(2) },
        }
      end
    end
  end
end
