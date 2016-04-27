# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron
# Learn more: http://github.com/javan/whenever

every :day, at: '3:00 am', roles: [:job_creator] do
  rake 'clear_expired_sessions'
end
