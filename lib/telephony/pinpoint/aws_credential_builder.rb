module Telephony
  module Pinpoint
    class AwsCredentialBuilder
      attr_reader :config

      # @param [Telephony::PinpointVoiceConfiguration, Telephony::PinpointSmsConfiguration] config
      def initialize(config)
        @config = config
      end

      def call
        if config.credential_role_arn && config.credential_role_session_name
          build_assumed_role_credential
        elsif config.access_key_id && config.secret_access_key
          build_access_key_credential
        end
      end

      private

      def build_assumed_role_credential
        Aws::AssumeRoleCredentials.new(
          role_arn: config.credential_role_arn,
          role_session_name: config.credential_role_session_name,
          external_id: config.credential_external_id,
          client: Aws::STS::Client.new(region: config.region),
        )

      # STS makes an HTTP call that can fail
      rescue Seahorse::Client::NetworkingError => e
        notify_role_failure(error: e, region: config.region)
        nil
      end

      def build_access_key_credential
        Aws::Credentials.new(
          config.access_key_id,
          config.secret_access_key,
        )
      end

      def notify_role_failure(error:, region:)
        error_log = { error: error, region: region }
        Telephony.config.logger.warn(error_log.to_json)
      end
    end
  end
end
