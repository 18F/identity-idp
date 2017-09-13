# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron
# Learn more: http://github.com/javan/whenever

set :output, '/srv/idp/shared/log/cron.log'
env :PATH, ENV['PATH']

require File.expand_path(File.dirname(__FILE__) + '/environment')

health_check = Whenever.seconds(Figaro.env.queue_health_check_frequency_seconds.to_i, :seconds)

every health_check, roles: [:job_creator] do
  runner 'WorkerHealthChecker.enqueue_dummy_jobs'
end

if FeatureManagement.enable_usps_verification?
  mail_batch = Whenever.seconds(Figaro.env.usps_mail_batch_hours.to_i, :hours)

  every mail_batch, roles: [:job_creator] do
    runner 'UspsUploader.new.run'
  end
end
