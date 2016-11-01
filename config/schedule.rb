# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron
# Learn more: http://github.com/javan/whenever

every :day, at: '3:00 am', roles: [:job_creator] do
  rake 'clear_expired_sessions'
end

require File.expand_path(File.dirname(__FILE__) + '/environment')

health_check = Whenever.seconds(Figaro.env.queue_health_check_frequency_seconds.to_i, :seconds)

every health_check, roles: [:job_creator] do
  runner 'WorkerHealthChecker.check'
  runner 'WorkerHealthChecker.enqueue_dummy_jobs'
end
