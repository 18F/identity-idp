cron_1m = '* * * * *'
cron_5m = '0/5 * * * *'
cron_1h = '0 * * * *'
cron_24h = '0 0 * * *'
gpo_cron_24h = '0 10 * * *' # 10am UTC is 5am EST/6am EDT

if defined?(Rails::Console)
  Rails.logger.info 'job_configurations: console detected, skipping schedule'
else
  # rubocop:disable Metrics/BlockLength
  Rails.application.configure do
    config.good_job.cron = {
      # Daily GPO letter mailings
      gpo_daily_letter: {
        class: 'GpoDailyJob',
        cron: gpo_cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send account deletion confirmation notifications
      account_reset_grant_requests_send_emails: {
        class: 'AccountReset::GrantRequestsAndSendEmails',
        cron: cron_5m,
        args: -> { [Time.zone.now] },
      },
      # Send Total Monthly Auths Report to S3
      total_monthly_auths: {
        class: 'Reports::TotalMonthlyAuthsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send Sp User Counts Report to S3
      sp_user_counts: {
        class: 'Reports::SpUserCountsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send Sp User Quotas Report to S3
      sp_user_quotas: {
        class: 'Reports::SpUserQuotasReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Proofing Costs Report to S3
      proofing_costs: {
        class: 'Reports::ProofingCostsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Agency Invoice Supplement Report to S3
      sp_invoice_supplement_by_iaa: {
        class: 'Reports::AgencyInvoiceIaaSupplementReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Combined Invoice Supplement Report to S3
      combined_invoice_supplement_report: {
        class: 'Reports::CombinedInvoiceSupplementReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      agreement_summary_report: {
        class: 'Reports::AgreementSummaryReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Total IAL2 Costs Report to S3
      total_ial2_costs: {
        class: 'Reports::TotalIal2CostsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # SP Active Users Report to S3
      sp_active_users_report: {
        class: 'Reports::SpActiveUsersReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send deleted user accounts to S3
      deleted_user_accounts: {
        class: 'Reports::DeletedUserAccountsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send GPO Report to S3
      gpo_report: {
        class: 'Reports::GpoReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send Monthly GPO Letter Requests Report to S3
      gpo_monthly_letter_requests: {
        class: 'Reports::MonthlyGpoLetterRequestsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Upload list of verification errors to S3
      verification_errors_report: {
        class: 'Reports::VerificationFailuresReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send Partner API reports to S3
      partner_api_reports: {
        class: 'Agreements::Reports::PartnerApiReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send daily auth report to S3
      daily_auths: {
        class: 'Reports::DailyAuthsReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday] },
      },
      # Send daily dropoffs report to S3
      daily_dropoffs: {
        class: 'Reports::DailyDropoffsReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday] },
      },
      # Sync opted out phone numbers from AWS
      phone_number_opt_out_sync_job: {
        class: 'PhoneNumberOptOutSyncJob',
        cron: cron_1h,
        args: -> { [Time.zone.now] },
      },
      # Queue heartbeat job to GoodJob
      heartbeat_job: {
        class: 'HeartbeatJob',
        cron: cron_5m,
      },
      # Queue psql stats job to GoodJob
      psql_stats_job: {
        class: 'PsqlStatsJob',
        cron: cron_1m,
        args: -> { [Time.zone.now] },
      },
      # Queue usps proofing job to GoodJob
      get_usps_proofing_results_job: {
        class: 'GetUspsProofingResultsJob',
        cron: IdentityConfig.store.get_usps_proofing_results_job_cron,
        args: -> { [Time.zone.now] },
      },
      # Periodically verify signature on ThreatMetrix javascript
      verify_threat_metrix_js: {
        class: 'ThreatMetrixJsVerificationJob',
        cron: cron_1h,
      },
      # Batch up IRS Attempts API events
      irs_attempt_events_aggregator: {
        class: 'IrsAttemptsEventsBatchJob',
        cron: cron_1h,
        args: -> { [Time.zone.now - 1.hour] },
      },
    }
  end
  # rubocop:enable Metrics/BlockLength

  Rails.logger.info 'job_configurations: jobs scheduled with good_job.cron'
end
