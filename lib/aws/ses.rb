##
# ActionMailer delivery method for SES inspired by https://github.com/drewblas/aws-ses
#
module Aws
  module SES
    class Base
      cattr_accessor :region_pool

      def initialize(*); end

      def deliver(mail)
        response = ses_client.send_raw_email(raw_message: { data: mail.to_s })
        mail.message_id = "#{response.message_id}@email.amazonses.com"
        response
      end

      alias deliver! deliver

      private

      def ses_client
        @ses_client ||= Aws::SES::Client.new(ses_client_options)
      end

      def ses_client_options
        opts = {
          # https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/timeout-duration.html
          retry_limit: 3,
          retry_backoff: ->(_context) { sleep(2) },
        }
        opts[:region] = pick_region_from_pool if Figaro.env.aws_ses_region_pool.present?
        opts
      end

      def pick_region_from_pool
        self.class.region_pool ||= build_region_pool
        region_pool.sample
      end

      def build_region_pool
        JSON.parse(Figaro.env.aws_ses_region_pool).flat_map do |region, weight|
          [region] * weight
        end
      end
    end
  end
end
