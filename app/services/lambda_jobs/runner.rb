require 'faraday'

module LambdaJobs
  class Runner
    attr_reader :job_class, :args

    def initialize(job_class:, args:)
      @job_class = job_class
      @args = args
    end

    def run()
      if LoginGov::Hostdata.in_datacenter? && AppConfig.env.aws_lambda_proofing_enabled == 'true'
        aws_lambda_client.invoke(
          function_name: function_name,
          invocation_type: 'Event',
          log_type: 'None',
          payload: args.to_json,
        )
      else
        Thread.new do
          sleep AppConfig.env.aws_lambda_proofing_enabled.to_i

          job_class.handle(
            event: args,
            context: nil
          ) do |result|
            Faraday.post(
              args[:callback_url],
              result.to_json,
              'X-API-AUTH-TOKEN' => AppConfig.env.resolution_proof_result_lambda_token,
              'Content-Type' => 'application/json'
            )
          end
        end
      end
    end

    def aws_lambda_client
      Aws::Lambda::Client.new(region: AppConfig.env.aws_region)
    end

    # Due to length limits, we can only use the first 10 characters of a git SHA
    def function_name
      "#{LoginGov::Hostdata.env}-idp-functions-#{job_name}Function:#{LambdaJobs::GIT_REF[0...10]}"
    end

    # @example
    #   new(job_class: IdentityIdpFunctions::ProofResolutionMock).job_name
    #   => "ProofResolutionMock"
    # @return [String]
    def job_name
      job_class.name.split('::').last
    end
  end
end
