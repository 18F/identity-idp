# frozen_string_literal: true

cron_5m = '0/5 * * * *'
cron_12m = '0/12 * * * *'
cron_1h = '0 * * * *'
cron_24h = '0 0 * * *'
cron_24h_1am = '0 1 * * *' # 1am UTC is 8pm EST/9pm EDT
gpo_cron_24h = '0 10 * * *' # 10am UTC is 5am EST/6am EDT
cron_1w = '0 0 * * 0'

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
      # Send new device alert notifications
      create_new_device_alert_send_emails: (
        if IdentityConfig.store.feature_new_device_alert_aggregation_enabled
          {
            class: 'CreateNewDeviceAlert',
            cron: cron_5m,
            args: -> { [Time.zone.now] },
          }
        end
      ),
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
      # Email user counts for specific issuer
      sp_issuer_user_counts: {
        class: 'Reports::SpIssuerUserCountsReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Combined Invoice Supplement Report to S3
      combined_invoice_supplement_report: {
        class: 'Reports::CombinedInvoiceSupplementReport',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      combined_invoice_supplement_report_v2: {
        class: 'Reports::CombinedInvoiceSupplementReportV2',
        cron: cron_24h_1am,
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
      # Send daily registrations report to S3
      daily_registrations: {
        class: 'Reports::DailyRegistrationsReport',
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
      # Queue usps in-person visit notifications job to GoodJob
      in_person_enrollments_ready_for_status_check_job: {
        class: 'InPerson::EnrollmentsReadyForStatusCheckJob',
        cron: IdentityConfig.store.in_person_enrollments_ready_job_cron,
        args: -> { [Time.zone.now] },
      },
      # Queue usps proofing job to GoodJob
      get_usps_proofing_results_job: {
        class: 'GetUspsProofingResultsJob',
        cron: IdentityConfig.store.get_usps_proofing_results_job_cron,
        args: -> { [Time.zone.now] },
      },
      # Queue usps proofing job to GoodJob for ready enrollments
      get_usps_ready_proofing_results_job: {
        class: 'GetUspsReadyProofingResultsJob',
        cron: IdentityConfig.store.get_usps_ready_proofing_results_job_cron,
        args: -> { [Time.zone.now] },
      },
      # Queue usps proofing job to GoodJob for waiting enrollments
      get_usps_waiting_proofing_results_job: {
        class: 'GetUspsWaitingProofingResultsJob',
        cron: IdentityConfig.store.get_usps_waiting_proofing_results_job_cron,
        args: -> { [Time.zone.now] },
      },
      # Queue daily in-person proofing reminder email job
      email_reminder_job: {
        class: 'InPerson::EmailReminderJob',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Periodically verify signature on ThreatMetrix javascript
      verify_threat_metrix_js: {
        class: 'ThreatMetrixJsVerificationJob',
        cron: cron_1h,
      },
      # Reject profiles that have been in fraud_review_pending for 30 days
      fraud_rejection: {
        class: 'FraudRejectionDailyJob',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send Duplicate SSN report to S3
      duplicate_ssn: {
        class: 'Reports::DuplicateSsnReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday] },
      },
      # Send Identity Verification report to S3
      identity_verification_report: {
        class: 'Reports::IdentityVerificationReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday] },
      },
      usps_auth_token_refresh: (if IdentityConfig.store.usps_auth_token_refresh_job_enabled
                                  {
                                    class: 'UspsAuthTokenRefreshJob',
                                    cron: cron_12m,
                                  }
                                end),
      # Account creation/deletion stats for OKRs
      quarterly_account_stats: {
        class: 'Reports::QuarterlyAccountStats',
        cron: cron_24h,
        args: -> { [Time.zone.today] },
      },
      # Send reminder letters for old, outstanding GPO verification codes
      send_gpo_code_reminders: {
        class: 'GpoReminderJob',
        cron: cron_24h,
        args: -> { [14.days.ago] },
      },
      # Expire old GPO profiles
      expire_gpo_profiles: {
        class: 'GpoExpirationJob',
        cron: cron_24h,
      },
      # Monthly report checking in on key metrics
      monthly_key_metrics_report: {
        class: 'Reports::MonthlyKeyMetricsReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday.end_of_day] },
      },
      # Send weekly authentication reports to partners
      weekly_authentication_report: {
        class: 'Reports::AuthenticationReport',
        cron: cron_1w,
        args: -> { [Time.zone.now] },
      },
      # Send fraud metrics to Team Judy
      fraud_metrics_report: {
        class: 'Reports::FraudMetricsReport',
        cron: cron_24h,
        args: -> { [Time.zone.yesterday.end_of_day] },
      },
    }.compact
  end
  # rubocop:enable Metrics/BlockLength

  Rails.logger.info 'job_configurations: jobs scheduled with good_job.cron'
end
