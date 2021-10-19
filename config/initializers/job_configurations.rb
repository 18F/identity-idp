require 'job_runner/runner'
require 'job_runner/job_configuration'

cron_5m = '0/5 * * * *'
interval_5m = 5 * 60
cron_1h = '0 * * * *'
interval_1h = 60 * 60
cron_24h = '0 0 * * *'
gpo_cron_24h = '0 10 * * *' # 10am UTC is 5am EST/6am EDT
inteval_24h = 24 * 60 * 60

# Once we enable ruby workers in prod, we can remove all the JobRunner code and config
# and just set this hash directly
all_configs = {
  # Daily GPO letter mailings
  gpo_daily_letter: {
    job_runner: {
      name: 'Send GPO letter',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { GpoDailyJob.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'GpoDailyJob',
      cron: gpo_cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send account deletion confirmation notifications
  account_reset_grant_requests_send_emails: {
    job_runner: {
      name: 'Account reset notice',
      interval: interval_5m,
      timeout: 4 * 60,
      callback: -> { AccountReset::GrantRequestsAndSendEmails.new.perform(Time.zone.now) },
      health_critical: true,
      failures_before_alarm: 2,
    },
    good_job: {
      class: 'AccountReset::GrantRequestsAndSendEmails',
      cron: cron_5m,
      args: -> { [Time.zone.now] },
    },
  },
  # Send OMB Fitara report to s3
  omb_fitara_report: {
    job_runner: {
      name: 'OMB Fitara report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::OmbFitaraReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::OmbFitaraReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Unique Monthly Auths Report to S3
  unique_monthly_auths: {
    job_runner: {
      name: 'Unique monthly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::UniqueMonthlyAuthsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::UniqueMonthlyAuthsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Unique Yearly Auths Report to S3
  unique_yearly_auths: {
    job_runner: {
      name: 'Unique yearly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::UniqueYearlyAuthsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::UniqueYearlyAuthsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Agency User Counts Report to S3
  agency_user_counts: {
    job_runner: {
      name: 'Agency user counts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyUserCountsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::AgencyUserCountsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Total Monthly Auths Report to S3
  total_monthly_auths: {
    job_runner: {
      name: 'Total montly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::TotalMonthlyAuthsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::TotalMonthlyAuthsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Sp User Counts Report to S3
  sp_user_counts: {
    job_runner: {
      name: 'SP user counts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpUserCountsReport.new.perform(Time.zone.now) },
    },
    good_job: {
      class: 'Reports::SpUserCountsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Sp User Quotas Report to S3
  sp_user_quotas: {
    job_runner: {
      name: 'SP user quotas report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpUserQuotasReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::SpUserQuotasReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Doc Auth Funnel Report to S3
  doc_auth_funnel_report: {
    job_runner: {
      name: 'Doc Auth Funnel Report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthFunnelReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::DocAuthFunnelReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Sp Success Rate Report to S3
  sp_success_rate: {
    job_runner: {
      name: 'SP success rate report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpSuccessRateReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::SpSuccessRateReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Proofing Costs Report to S3
  proofing_costs: {
    job_runner: {
      name: 'Proofing costs report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::ProofingCostsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::ProofingCostsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Doc auth drop off rates per sprint to S3
  doc_auth_dropoff_per_sprint: {
    job_runner: {
      name: 'Doc auth drop off rates per sprint report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthDropOffRatesPerSprintReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::DocAuthDropOffRatesPerSprintReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # SP Costs Report to S3
  sp_costs: {
    job_runner: {
      name: 'SP cost report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpCostReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::SpCostReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Agency Invoice Supplement Report to S3
  sp_invoice_supplement_by_iaa: {
    job_runner: {
      name: 'SP Invoice supplement report by IAA',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyInvoiceIaaSupplementReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::AgencyInvoiceIaaSupplementReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Agency Invoice Supplement Report to S3
  sp_invoice_supplement_by_issuer: {
    job_runner: {
      name: 'SP Invoice supplement report by issuer',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyInvoiceIssuerSupplementReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::AgencyInvoiceIssuerSupplementReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Total SP Costs Report to S3
  total_sp_costs: {
    job_runner: {
      name: 'Total SP cost report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::TotalSpCostReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::TotalSpCostReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # SP Active Users Report to S3
  sp_active_users_report: {
    job_runner: {
      name: 'SP active users report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpActiveUsersReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::SpActiveUsersReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # SP Active Users Report to S3
  sp_active_users_period_pf_performance: {
    job_runner: {
      name: 'SP active users over period of peformance report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> do
        Reports::SpActiveUsersOverPeriodOfPerformanceReport.new.perform(Time.zone.today)
      end,
    },
    good_job: {
      class: 'Reports::SpActiveUsersOverPeriodOfPerformanceReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Doc auth drop off rates report
  doc_auth_dropoff_rates: {
    job_runner: {
      name: 'Doc auth drop off rates report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthDropOffRatesReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::DocAuthDropOffRatesReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # IAA Billing Report
  iaa_billing_report: {
    job_runner: {
      name: 'IAA billing report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::IaaBillingReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::IaaBillingReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send deleted user accounts to S3
  deleted_user_accounts: {
    job_runner: {
      name: 'Deleted user accounts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DeletedUserAccountsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::DeletedUserAccountsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send GPO Report to S3
  gpo_report: {
    job_runner: {
      name: 'GPO report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::GpoReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::GpoReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Monthly GPO Letter Requests Report to S3
  gpo_monthly_letter_requests: {
    job_runner: {
      name: 'Monthly GPO letter requests report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::MonthlyGpoLetterRequestsReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Reports::MonthlyGpoLetterRequestsReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send Partner API reports to S3
  partner_api_reports: {
    job_runner: {
      name: 'Partner API report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Agreements::Reports::PartnerApiReport.new.perform(Time.zone.today) },
    },
    good_job: {
      class: 'Agreements::Reports::PartnerApiReport',
      cron: cron_24h,
      args: -> { [Time.zone.today] },
    },
  },
  # Send daily auth report to S3
  daily_auths: {
    job_runner: {
      name: 'Daily Auth Report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DailyAuthsReport.new.perform(Time.zone.yesterday) },
    },
    good_job: {
      class: 'Reports::DailyAuthsReport',
      cron: cron_24h,
      args: -> { [Time.zone.yesterday] },
    },
  },
  # Send daily dropoffs report to S3
  daily_dropoffs: {
    job_runner: {
      name: 'Daily Dropoffs Report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DailyDropoffsReport.new.perform(Time.zone.yesterday) },
    },
    good_job: {
      class: 'Reports::DailyDropoffsReport',
      cron: cron_24h,
      args: -> { [Time.zone.yesterday] },
    },
  },
  # Removes old rows from the Throttles table
  remove_old_throttles: {
    job_runner: {
      name: 'Remove Old Throttles',
      interval: interval_1h,
      timeout: 300,
      callback: -> { RemoveOldThrottlesJob.new.perform(Time.zone.now) },
    },
    good_job: {
      class: 'RemoveOldThrottlesJob',
      cron: cron_1h,
      args: -> { [Time.zone.now] },
    },
  },
}

if IdentityConfig.store.ruby_workers_cron_enabled
  # Queue heartbeat job to GoodJob
  all_configs[:heartbeat_job] = {
    good_job: {
      class: 'HeartbeatJob',
      cron: cron_5m,
    },
  }
end

if defined?(Rails::Console)
  Rails.logger.info 'job_configurations: console detected, skipping schedule'
elsif IdentityConfig.store.ruby_workers_cron_enabled
  Rails.application.configure do
    config.good_job.cron = all_configs.transform_values { |config| config.fetch(:good_job) }
  end

  Rails.logger.info 'job_configurations: jobs scheduled with good_job.cron'
else
  all_configs.each do |_key, config|
    JobRunner::Runner.add_config(
      JobRunner::JobConfiguration.new(**config.fetch(:job_runner)),
    )
  end

  Rails.logger.info 'job_configurations: jobs scheduled with JobRunner::Runner'
end
