cron_5m = '0/5 * * * *'
interval_5m = 5 * 60
cron_24h = '0 0 * * *'
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
      callback: -> { GpoDailyJob.new.perform },
    },
    good_job: {
      class: 'GpoDailyJob',
      cron: cron_24h,
    },
  },
  # Send account deletion confirmation notifications
  account_reset_grant_requests_send_emails: {
    job_runner: {
      name: 'Account reset notice',
      interval: interval_5m,
      timeout: 4 * 60,
      callback: -> { AccountReset::GrantRequestsAndSendEmails.new.perform },
      health_critical: true,
      failures_before_alarm: 2,
    },
    good_job: {
      class: 'AccountReset::GrantRequestsAndSendEmails',
      cron: cron_5m,
    },
  },
  # Send OMB Fitara report to s3
  omb_fitara_report: {
    job_runner: {
      name: 'OMB Fitara report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::OmbFitaraReport.new.perform },
    },
    good_job: {
      class: 'Reports::OmbFitaraReport',
      cron: cron_24h,
    },
  },
  # Send Unique Monthly Auths Report to S3
  unique_monthly_auths: {
    job_runner: {
      name: 'Unique monthly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::UniqueMonthlyAuthsReport.new.perform },
    },
    good_job: {
      class: 'Reports::UniqueMonthlyAuthsReport',
      cron: cron_24h,
    },
  },
  # Send Unique Yearly Auths Report to S3
  unique_yearly_auths: {
    job_runner: {
      name: 'Unique yearly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::UniqueYearlyAuthsReport.new.perform },
    },
    good_job: {
      class: 'Reports::UniqueYearlyAuthsReport',
      cron: cron_24h,
    },
  },
  # Send Agency User Counts Report to S3
  agency_user_counts: {
    job_runner: {
      name: 'Agency user counts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyUserCountsReport.new.perform },
    },
    good_job: {
      class: 'Reports::AgencyUserCountsReport',
      cron: cron_24h,
    },
  },
  # Send Total Monthly Auths Report to S3
  total_monthly_auths: {
    job_runner: {
      name: 'Total montly auths report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::TotalMonthlyAuthsReport.new.perform },
    },
    good_job: {
      class: 'Reports::TotalMonthlyAuthsReport',
      cron: cron_24h,
    },
  },
  # Send Sp User Counts Report to S3
  sp_user_counts: {
    job_runner: {
      name: 'SP user counts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpUserCountsReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpUserCountsReport',
      cron: cron_24h,
    },
  },
  # Send Sp User Quotas Report to S3
  sp_user_quotas: {
    job_runner: {
      name: 'SP user quotas report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpUserQuotasReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpUserQuotasReport',
      cron: cron_24h,
    },
  },
  # Send Doc Auth Funnel Report to S3
  doc_auth_funnel_report: {
    job_runner: {
      name: 'Doc Auth Funnel Report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthFunnelReport.new.perform },
    },
    good_job: {
      class: 'Reports::DocAuthFunnelReport',
      cron: cron_24h,
    },
  },
  # Send Sp Success Rate Report to S3
  sp_success_rate: {
    job_runner: {
      name: 'SP success rate report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpSuccessRateReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpSuccessRateReport',
      cron: cron_24h,
    },
  },
  # Proofing Costs Report to S3
  proofing_costs: {
    job_runner: {
      name: 'Proofing costs report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::ProofingCostsReport.new.perform },
    },
    good_job: {
      class: 'Reports::ProofingCostsReport',
      cron: cron_24h,
    },
  },
  # Doc auth drop off rates per sprint to S3
  doc_auth_dropoff_per_sprint: {
    job_runner: {
      name: 'Doc auth drop off rates per sprint report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthDropOffRatesPerSprintReport.new.perform },
    },
    good_job: {
      class: 'Reports::DocAuthDropOffRatesPerSprintReport',
      cron: cron_24h,
    },
  },
  # SP Costs Report to S3
  sp_costs: {
    job_runner: {
      name: 'SP cost report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpCostReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpCostReport',
      cron: cron_24h,
    },
  },
  # Agency Invoice Supplement Report to S3
  sp_invoice_supplement_by_iaa: {
    job_runner: {
      name: 'SP Invoice supplement report by IAA',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyInvoiceIaaSupplementReport.new.perform },
    },
    good_job: {
      class: 'Reports::AgencyInvoiceIaaSupplementReport',
      cron: cron_24h,
    },
  },
  # Agency Invoice Supplement Report to S3
  sp_invoice_supplement_by_issuer: {
    job_runner: {
      name: 'SP Invoice supplement report by issuer',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::AgencyInvoiceIssuerSupplementReport.new.perform },
    },
    good_job: {
      class: 'Reports::AgencyInvoiceIssuerSupplementReport',
      cron: cron_24h,
    },
  },
  # Total SP Costs Report to S3
  total_sp_costs: {
    job_runner: {
      name: 'Total SP cost report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::TotalSpCostReport.new.perform },
    },
    good_job: {
      class: 'Reports::TotalSpCostReport',
      cron: cron_24h,
    },
  },
  # SP Active Users Report to S3
  sp_active_users_report: {
    job_runner: {
      name: 'SP active users report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpActiveUsersReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpActiveUsersReport',
      cron: cron_24h,
    },
  },
  # SP Active Users Report to S3
  sp_active_users_period_pf_performance: {
    job_runner: {
      name: 'SP active users over period of peformance report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::SpActiveUsersOverPeriodOfPerformanceReport.new.perform },
    },
    good_job: {
      class: 'Reports::SpActiveUsersOverPeriodOfPerformanceReport',
      cron: cron_24h,
    },
  },
  # Doc auth drop off rates report
  doc_auth_dropoff_rates: {
    job_runner: {
      name: 'Doc auth drop off rates report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DocAuthDropOffRatesReport.new.perform },
    },
    good_job: {
      class: 'Reports::DocAuthDropOffRatesReport',
      cron: cron_24h,
    },
  },
  # IAA Billing Report
  iaa_billing_report: {
    job_runner: {
      name: 'IAA billing report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::IaaBillingReport.new.perform },
    },
    good_job: {
      class: 'Reports::IaaBillingReport',
      cron: cron_24h,
    },
  },
  # Send deleted user accounts to S3
  deleted_user_accounts: {
    job_runner: {
      name: 'Deleted user accounts report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DeletedUserAccountsReport.new.perform },
    },
    good_job: {
      class: 'Reports::DeletedUserAccountsReport',
      cron: cron_24h,
    },
  },
  # Send GPO Report to S3
  gpo_report: {
    job_runner: {
      name: 'GPO report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::GpoReport.new.perform },
    },
    good_job: {
      class: 'Reports::GpoReport',
      cron: cron_24h,
    },
  },
  # Send Monthly GPO Letter Requests Report to S3
  gpo_monthly_letter_requests: {
    job_runner: {
      name: 'Monthly GPO letter requests report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::MonthlyGpoLetterRequestsReport.new.perform },
    },
    good_job: {
      class: 'Reports::MonthlyGpoLetterRequestsReport',
      cron: cron_24h,
    },
  },
  # Send Partner API reports to S3
  partner_api_reports: {
    job_runner: {
      name: 'Partner API report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Agreements::Reports::PartnerApiReport.new.perform },
    },
    good_job: {
      class: 'Agreements::Reports::PartnerApiReport',
      cron: cron_24h,
    },
  },
  # Send daily auth report to S3
  daily_auths: {
    job_runner: {
      name: 'Daily Auth Report',
      interval: inteval_24h,
      timeout: 300,
      callback: -> { Reports::DailyAuthsReport.new.perform },
    },
    good_job: {
      class: 'Reports::DailyAuthsReport',
      cron: cron_24h,
    },
  },
}

if IdentityConfig.store.ruby_workers_enabled
  # Queue heartbeat job to DelayedJob
  all_configs[:heartbeat_job] = {
    good_job: {
      class: 'HeartbeatJob',
      cron: cron_5m,
    },
  }
end

if IdentityConfig.store.ruby_workers_enabled
  Rails.application.configure do |config|
    config.good_job.cron = all_configs.transform_values { |config| config.fetch(:good_job) }
  end
else
  require 'job_runner/runner'
  require 'job_runner/job_configuration'

  all_configs.each do |_key, config|
    JobRunner::Runner.add_config(
      JobRunner::JobConfiguration.new(**config.fetch(:job_runner)),
    )
  end
end
