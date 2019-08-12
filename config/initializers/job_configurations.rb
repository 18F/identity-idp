# Daily GPO letter mailings
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Send GPO letter',
  interval: 24 * 60 * 60,
  timeout: 300,
  callback: lambda {
    UspsConfirmationUploader.new.run unless HolidayService.observed_holiday?(Time.zone.today)
  },
)

# Send account deletion confirmation notifications
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Account reset notice',
  interval: 5 * 60, # 5 minutes
  timeout: 4 * 60,
  callback: -> { AccountReset::GrantRequestsAndSendEmails.new.call },
  health_critical: true,
  failures_before_alarm: 2,
)

# Send OMB Fitara report to s3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'OMB Fitara report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::OmbFitaraReport.new.call },
)

# Send Unique Monthly Auths Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Unique montly auths report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::UniqueMonthlyAuthsReport.new.call },
)

# Send Agency User Counts Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Agency user counts report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::AgencyUserCountsReport.new.call },
)

# Send Total Monthly Auths Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Total montly auths report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::TotalMonthlyAuthsReport.new.call },
)

# Send Sp User Counts Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP user counts report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpUserCountsReport.new.call },
)
