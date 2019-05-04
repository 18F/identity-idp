require Rails.root.join('lib', 'job_runner.rb')

#JobRunner::JobConfiguration.new(name: 'test', interval: 60, callback: proc{ Rails.logger.info("Hello from testjob"); "This is a result"})
#JobRunner::JobConfiguration.new(name: 'test', interval: 60, timeout: 30, callback: proc{ exit })
JobRunner::JobConfiguration.new(name: 'test', interval: 300, timeout: 10, callback: proc{ Rails.logger.info("Hello from testjob"); "This is a result"})
