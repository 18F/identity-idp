# frozen_string_literal: true

##
# ActionMailer delivery method for SES inspired by https://github.com/drewblas/aws-ses
#
module Aws
  module SES
    class Base
      SES_CLIENT_POOL = ConnectionPool.new(size: IdentityConfig.store.aws_ses_client_pool_size) do
        # https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/timeout-duration.html
        Aws::SES::Client.new(
          retry_limit: 3,
          retry_backoff: ->(_context) { sleep(1) },
          instance_profile_credentials_timeout: 1, # defaults to 1 second
          instance_profile_credentials_retries: 5, # defaults to 0 retries
        )
      end.freeze

      def initialize(*); end

      def deliver(mail)
        response = SES_CLIENT_POOL.with do |client|
          client.send_raw_email(
            raw_message: { data: mail.to_s },
            configuration_set_name: IdentityConfig.store.ses_configuration_set_name,
          )
        end

        mail.header[:ses_message_id] = response.message_id
        response
      end

      alias_method :deliver!, :deliver
    end
  end
end
