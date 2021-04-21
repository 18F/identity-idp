require 'aws-sdk-ssm'

module IdentityIdpFunctions
  class SsmHelper
    # @return [String]
    def load(parameter_name)
      ssm_client.get_parameter(
        name: "/#{env_name}/idp/doc-capture/#{parameter_name}",
        with_decryption: true,
      ).parameter.value
    end

    def ssm_client
      @ssm_client ||= Aws::SSM::Client.new(
        http_idle_timeout: 3,
        http_open_timeout: 3,
        http_read_timeout: 3,
      )
    end

    # prod, dev, int, etc
    def env_name
      ENV['ENVIRONMENT_NAME']
    end
  end
end
