require Rails.root.join('lib', 'job_runner.rb')

JobRunner::JobConfiguration.new(name: 'test', interval: 60, callback: proc{ Rails.logger.info("Hello from testjob")})
