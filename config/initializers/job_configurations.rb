require 'job_runner/runner'
require 'job_runner/job_configuration'

# Daily GPO letter mailings
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Send GPO letter',
  interval: 24 * 60 * 60,
  timeout: 300,
  callback: lambda do
    GpoDailyTestSender.new.run

    GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(Time.zone.today)
  end,
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

# Send Unique Yearly Auths Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Unique yearly auths report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::UniqueYearlyAuthsReport.new.call },
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

# Send Sp User Quotas Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP user quotas report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpUserQuotasReport.new.call },
)

# Send Doc Auth Funnel Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Doc Auth Funnel Report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::DocAuthFunnelReport.new.call },
)

# Send Sp Success Rate Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP success rate report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpSuccessRateReport.new.call },
)

# Proofing Costs Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Proofing costs report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::ProofingCostsReport.new.call },
)

# Proofing Costs Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Doc auth drop off rates per sprint report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::DocAuthDropOffRatesPerSprintReport.new.call },
)

# SP Costs Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP cost report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpCostReport.new.call },
)

# Agency Invoice Supplement Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP Invoice supplement report by IAA',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::AgencyInvoiceIaaSupplementReport.new.call },
)

# Agency Invoice Supplement Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP Invoice supplement report by issuer',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::AgencyInvoiceIssuerSupplementReport.new.call },
)

# Total SP Costs Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Total SP cost report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::TotalSpCostReport.new.call },
)

# SP Active Users Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP active users report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpActiveUsersReport.new.call },
)

# SP Active Users Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'SP active users over period of peformance report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::SpActiveUsersOverPeriodOfPerformanceReport.new.call },
)

# Doc auth drop off rates report
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Doc auth drop off rates report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::DocAuthDropOffRatesReport.new.call },
)

# IAA Billing Report
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'IAA billing report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::IaaBillingReport.new.call },
)

# Send Agency User Counts Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Deleted user accounts report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::DeletedUserAccountsReport.new.call },
)

# Send GPO Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'GPO report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::GpoReport.new.call },
)

# Send Monthly GPO Letter Requests Report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Monthly GPO letter requests report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::MonthlyGpoLetterRequestsReport.new.call },
)

# Send Partner API reports to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Partner API report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Agreements::Reports::PartnerApiReport.new.run },
)

# Send daily auth report to S3
JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
  name: 'Daily Auth Report',
  interval: 24 * 60 * 60, # 24 hours
  timeout: 300,
  callback: -> { Reports::DailyAuthsReport.new(Date.yesterday).call },
)

if IdentityConfig.store.ruby_workers_enabled
  # Queue heartbeat job to DelayedJob
  JobRunner::Runner.add_config JobRunner::JobConfiguration.new(
    name: 'Job Queue Heartbeat',
    interval: 5 * 60, # 5 minutes
    timeout: 4 * 60,
    callback: -> do
      HeartbeatJob.perform_later
    end,
    health_critical: false,
    failures_before_alarm: 0,
  )
end
