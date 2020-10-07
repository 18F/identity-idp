module LambdaJobs
  class Runner
    attr_reader :job_name, :job_class, :args

    def initialize(job_name:, job_class:, args:)
      @job_name = job_name
      @job_class = job_class
      @args = args
    end

    def run(&local_callback)
      if LoginGov::Hostdata.in_datacenter? && Figaro.env.aws_lambda_proofing_enabled == 'true'
        aws_lambda_client.invoke(
          function_name: function_name,
          invocation_type: 'Event',
          log_type: 'None',
          payload: args.to_json,
        )
      else
        job_class.handle(
          event: { 'body' => args.to_json },
          context: nil,
          &local_callback
        )
      end
    end

    def aws_lambda_client
      Aws::Lambda::Client.new(region: Figaro.env.aws_region)
    end

    # Due to length limits, we can only use the first 10 characters of a git SHA
    def function_name
      "#{job_name}:#{LambdaJobs::GIT_REF[0...10]}"
    end
  end
end
