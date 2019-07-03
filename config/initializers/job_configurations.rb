# Daily GPO letter mailings
JobRunner::Runner.configurations << JobRunner::JobConfiguration.new(
  name: 'Send GPO letter',
  interval: 24 * 60 * 60,
  timeout: 300,
  callback: lambda {
    UspsConfirmationUploader.new.run unless HolidayService.observed_holiday?(Time.zone.today)
  },
)

# Send account deletion confirmation notifications
JobRunner::Runner.configurations << JobRunner::JobConfiguration.new(
  name: 'Account reset notice',
  interval: 5 * 60, # 5 minutes
  timeout: 4 * 60,
  callback: -> { AccountReset::GrantRequestsAndSendEmails.new.call },
)
