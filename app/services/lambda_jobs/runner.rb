module LambdaJobs
  class Runner
    # shorthand for new.run, easier to stub
    def self.execute(**args)
      new(**args).run
    end

    attr_reader :job_name, :job_class, :args

    def initialize(job_name:, args:, job_class:)
      @job_name = job_name
      @args = args
      @job_class = job_class
    end

    def run
      if LoginGov::Hostdata.in_datacenter?
        execute_lambda
      else
        execute_inline
      end
    end

    def execute_lambda
      client = Aws::Lambda::Client.new(region: Figaro.env.aws_region)
      client.invoke(
        function_name: "#{job_name}@#{LambdaJobs::GIT_REF}", # TODO: resolve SHA better
        invocation_type: 'Event',
        log_type: 'None',
        payload: args.to_json
      )
    end

    def execute_inline
      job_class.handle(
        event: { body: args.to_json },
        context: nil,
      )
    end
  end
end
