module LambdaJobs
  class Runner
    def self.execute(job_name:, args:)
      if LoginGov::Hostdata.in_datacenter?
        Aws::Lambda.execute(job_name: job_name, revision: LambdaJobs::Runner::GIT_REF)
      else
        # todo: figure out a way to dispatch this better?
        Identity::Idp::Functions::ProoferJob.handle(event: {}, context: args.to_json)
      end
    end
  end
end