##
# ActionMailer delivery method for SES inspired by https://github.com/drewblas/aws-ses
#
module Aws
  module SES
    class Base
      def initialize(*); end

      def deliver(mail)
        response = ses_client.send_raw_email(raw_message: { data: mail.to_s })
        mail.message_id = "#{response.message_id}@email.amazonses.com"
        response
      end

      alias deliver! deliver

      private

      def ses_client
        @ses_client ||= Aws::SES::Client.new(region: Figaro.env.aws_region)
      end
    end
  end
end
