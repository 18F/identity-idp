# frozen_string_literal: true

require 'csv'
#require_relative 'app/jobs/reports/base_report.rb'

module Reports
  class IRSMonthlyCredMetrics < BaseReport
    REPORT_NAME = 'irs_monthly_cred_metrics'
    

    def perform(_date)
      return unless IdentityConfig.store.s3_reports_enabled
      binding.pry
      iaas = IaaReportingHelper.iaas.filter { |x| x.end_date > 30.days.ago }
      
      csv = build_csv(iaas, IaaReportingHelper.partner_accounts)
      save_report(REPORT_NAME, csv, extension: 'csv')
      message = "Report: #{REPORT_NAME}"
      subject = "IRS Monthly Credential Metrics"
    
      report_configs.each do |report_hash|
        reports = monthly_credentials_emailable_reports(report_hash['issuers'])

        report_hash['emails'].each do |email|
          ReportMailer.tables_report(
            email:,
            subject:,
            message:,
            reports: ,
            attachment_format: :csv,
          ).deliver_now
        end
      end
    end

    # @param [Array<IaaReportingHelper::IaaConfig>] iaas
    # @param [Array<IaaReportingHelper::PartnerConfig>] partner_accounts
    # @return [String] CSV report
    def monthly_credentials_emailable_reports(issuer)
      last_month_start = Date.today.last_month.beginning_of_month
      last_month_end = Date.today.last_month.end_of_month
    
      by_iaa_results = iaas.flat_map do |iaa|
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(
          key: iaa.key,
          issuers: iaa.issuers,
          start_date: iaa.start_date,
          end_date: iaa.end_date,
        )
      end

      by_issuer_results = iaas.flat_map do |iaa|
        iaa.issuers.flat_map do |issuer|
          Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow.call(
            issuer: issuer,
            iaa_start_date: iaa.start_date,
            iaa_end_date: iaa.end_date,
            iaa: iaa.key,
          )
        end
      end

      by_partner_results = partner_accounts.flat_map do |partner_account|
        Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner.call(
          partner: partner_account.partner,
          issuers: partner_account.issuers,
          start_date: partner_account.start_date,
          end_date: partner_account.end_date,
        )
      end

      by_issuer_profile_age_results = partner_accounts.flat_map do |partner_account|
        partner_account.issuers.flat_map do |issuer|
          Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner.call(
            partner: partner_account.partner,
            issuers: [issuer],
            start_date: partner_account.start_date,
            end_date: partner_account.end_date,
          )
        end
      end

      combine_by_iaa_month(
        by_iaa_results: by_iaa_results,
        by_issuer_results: by_issuer_results,
        by_partner_results: by_partner_results,
        by_issuer_profile_age_results: by_issuer_profile_age_results,
      )
    end

    def combine_by_iaa_month(
      by_iaa_results:,
      by_issuer_results:,
      by_partner_results:,
      by_issuer_profile_age_results:
    )
      by_iaa_and_year_month = by_iaa_results.group_by do |result|
        [result[:key], result[:year_month]]
      end

      by_issuer_iaa_issuer_year_months = by_issuer_results
        .group_by { |r| r[:iaa] }
        .transform_values do |iaa|
          iaa.group_by { |r| r[:issuer] }
            .transform_values { |issuer| issuer.group_by { |r| r[:year_month] } }
        end

      # rubocop:disable Metrics/BlockLength
      CSV.generate do |csv|
        csv << [
          # todo: still need to determine which of the following need to be3 removed from this report
          'iaa_order_number',
          'partner',
          'iaa_start_date',
          'iaa_end_date',

          'issuer',
          'friendly_name',

          'year_month',
          'year_month_readable',

          'credentials_authorized_requesting_agency',
          'new_identity_verification_credentials_authorized_for_partner',
          'existing_identity_verification_credentials_authorized_for_partner',
        ]
        by_issuer_iaa_issuer_year_months.each do |iaa_key, issuer_year_months|
          issuer_year_months.each do |issuer, year_months_data|
            friendly_name = ServiceProvider.find_by(issuer: issuer).friendly_name
            year_months = year_months_data.keys.sort

            year_months.each do |year_month|
              iaa_results = by_iaa_and_year_month[ [iaa_key, year_month] ]
              if !iaa_results
                logger.warn(
                  {
                    level: 'warning',
                    name: 'missing iaa_results',
                    iaa: iaa_key,
                    year_month: year_month,
                  }.to_json,
                )
                next
              end

              issuer_results = year_months_data[year_month]
              year_month_start = Date.strptime(year_month, '%Y%m')
              iaa_start_date = Date.parse(iaa_results.first[:iaa_start_date])
              iaa_end_date = Date.parse(iaa_results.first[:iaa_end_date])

              partner_results = by_partner_results.find do |result|
                result[:year_month] == year_month && result[:issuers]&.include?(issuer)
              end || {}

              issuer_profile_age_results = by_issuer_profile_age_results.find do |result|
                result[:year_month] == year_month && result[:issuers]&.include?(issuer)
              end || {}

              csv << [
                iaa_key,
                partner_results[:partner],
                iaa_start_date,
                iaa_end_date,

                issuer,
                friendly_name,

                year_month,
                year_month_start.strftime('%B %Y'),

                # todo: these new lines are NOT being written out
                # additional values for IRS specifically
                # this line is what we need for Credentials authorized Requesting Agency
                extract(
                  issuer_results, :total_auth_count,
                  ial: 1
                ) + extract(issuer_results, :total_auth_count, ial: 2),
                # New identity verification/Credentials Authorized for Partner
                ((partner_results[:partner_ial2_new_unique_user_events_year1] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_year2] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_year3] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_year4] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_year5] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_year_greater_than_5] || 0) +
                (partner_results[:partner_ial2_new_unique_user_events_unknown] || 0)),

                # Existing identity verification/Credentials Authorized for Partner
                (((issuer_profile_age_results[:partner_ial2_unique_user_events_year1] || 0) +
                (issuer_profile_age_results[:partner_ial2_unique_user_events_year2] || 0) +
                (issuer_profile_age_results[:partner_ial2_unique_user_events_year3] || 0) +
                (issuer_profile_age_results[:partner_ial2_unique_user_events_year4] || 0) +
                (issuer_profile_age_results[:partner_ial2_unique_user_events_year5] || 0) +
                (issuer_profile_age_results[:partner_ial2_unique_user_events_year_greater_than_5] || 0)+ # rubocop:disable Layout/LineLength
                (issuer_profile_age_results[:partner_ial2_unique_user_events_unknown] || 0)) -
                ((issuer_profile_age_results[:partner_ial2_new_unique_user_events_year1] || 0) +
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year2] || 0) +
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year3] || 0) +
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year4] || 0) +
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year5] || 0) +
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year_greater_than_5] || 0) + # rubocop:disable Layout/LineLength
                (issuer_profile_age_results[:partner_ial2_new_unique_user_events_unknown] || 0))),
              ]
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end

    def monthly_credentials_emailable_reports(issuers)
      Reporting::CredentialReport.new(
        issuers:,
        time_range: report_date.all_month,
      ).as_emailable_reports
    end

    def report_configs
      IdentityConfig.store.irs_invoice_report_config
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
