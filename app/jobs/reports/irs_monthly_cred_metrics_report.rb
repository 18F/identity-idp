# frozen_string_literal: true

require 'csv'
#require_relative 'app/jobs/reports/base_report.rb'


module Reports
  class IrsMonthlyCredMetricsReport < BaseReport
    REPORT_NAME = 'irs_monthly_cred_metrics'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end


    def perform(_date = Time.zone.yesterday.end_of_day)
      @report_date = _date
      return unless IdentityConfig.store.s3_reports_enabled
      
      issuers = Agreements::PartnerAccount.find_by(name: "IRS")&.iaa_gtcs&.flat_map(&:service_providers)&.map(&:issuer)&.compact || []
      iaas = IaaReportingHelper.iaas.filter do |x|
        x.end_date > 90.days.ago && (x.issuers & issuers).any?
      end
      #iaas = IaaReportingHelper.iaas.filter { |x| x.end_date > 90.days.ago }
      csv = build_csv(iaas, IaaReportingHelper.partner_accounts, report_date)

      #save_report(REPORT_NAME, csv, extension: 'csv')
      message = "Report: #{REPORT_NAME}"
      subject = "IRS Monthly Credential Metrics"
      email_addresses = emails.select(&:present?)

      #issuer = issuers.select(&:present?)
      #report_configs.each do |report_hash|
        # Check if any emails are found
      binding.pry
      if email_addresses.empty?
       Rails.logger.warn 'No email addresses received - IRS Monthly Credential Report NOT SENT'
       return false
      end
      report = as_emailable_irs_report(iaas: iaas, partner_accounts: IaaReportingHelper.partner_accounts, date: report_date)
      upload_to_s3(report.table, report_date, report_name: REPORT_NAME)
      ReportMailer.tables_report(
        email: email_addresses,
        subject: subject,
        message: message,
        reports: report,
        attachment_format: :csv,
      )

    end

    def as_emailable_irs_report(iaas:, partner_accounts:, date:)
        Reporting::EmailableReport.new(
          title: "IRS Monthly Credential Metrics #{date.strftime('%B %Y')}",
          table: CSV.parse(build_csv(iaas, partner_accounts, date)),
          filename: 'irs_cred_metrics',
        )
    end

    # @return [String]
    def preamble(env: Identity::Hostdata.env || 'local')
      ERB.new(<<~ERB).result(binding).html_safe # rubocop:disable Rails/OutputSafety
        <% if env != 'prod' %>
          <div class="usa-alert usa-alert--info usa-alert--email">
            <div class="usa-alert__body">
              <%#
                NOTE: our AlertComponent doesn't support heading content like this uses,
                so for a one-off outside the Rails pipeline it was easier to inline the HTML here.
              %>
              <h2 class="usa-alert__heading">
                Non-Production Report
              </h2>
              <p class="usa-alert__text">
                This was generated in the <strong><%= env %></strong> environment.
              </p>
            </div>
          </div>
        <% end %>
      ERB
    end

    # @param [Array<IaaReportingHelper::IaaConfig>] iaas
    # @param [Array<IaaReportingHelper::PartnerConfig>] partner_accounts
    # @return [String] CSV report
    def build_csv(iaas, partner_accounts, report_date)
      report_month_start = report_date.beginning_of_month
      report_month_end = report_date.end_of_month
      by_iaa_results = iaas.flat_map do |iaa|
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(
          key: iaa.key,
          issuers: iaa.issuers,
          start_date: report_month_start,
          end_date: report_month_end,
        )
      end

      by_issuer_results = iaas.flat_map do |iaa|
        iaa.issuers.flat_map do |issuer|
          Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow.call(
            issuer: issuer,
            iaa_start_date: report_month_start,
            iaa_end_date: report_month_end,
            iaa: iaa.key,
          )
        end
      end

      by_partner_results = partner_accounts.flat_map do |partner_account|
        Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner.call(
          partner: partner_account.partner,
          issuers: partner_account.issuers,
          start_date: report_month_start,
          end_date: report_month_end,
        )
      end

      by_issuer_profile_age_results = partner_accounts.flat_map do |partner_account|
        partner_account.issuers.flat_map do |issuer|
          Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner.call(
            partner: partner_account.partner,
            issuers: [issuer],
            start_date: report_month_start,
            end_date: report_month_end,
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

    # def combine_by_iaa_month(
    #   by_iaa_results:,
    #   by_issuer_results:,
    #   by_partner_results:,
    #   by_issuer_profile_age_results:
    # )
    #   by_iaa_and_year_month = by_iaa_results.group_by do |result|
    #     [result[:key], result[:year_month]]
    #   end

    #   by_issuer_iaa_issuer_year_months = by_issuer_results
    #     .group_by { |r| r[:iaa] }
    #     .transform_values do |iaa|
    #       iaa.group_by { |r| r[:issuer] }
    #         .transform_values { |issuer| issuer.group_by { |r| r[:year_month] } }
    #     end

    #   # rubocop:disable Metrics/BlockLength
    #   CSV.generate do |csv|
    #     csv << [
    #       # todo: still need to determine which of the following need to be3 removed from this report
    #       'iaa_order_number',
    #       'partner',
    #       'iaa_start_date',
    #       'iaa_end_date',
    #       'issuer',
    #       'friendly_name',
    #       'year_month',
    #       'year_month_readable',
    #       'credentials_authorized_requesting_agency',
    #       'new_identity_verification_credentials_authorized_for_partner',
    #       'existing_identity_verification_credentials_authorized_for_partner',
    #     ]
    #     by_issuer_iaa_issuer_year_months.each do |iaa_key, issuer_year_months|
    #       issuer_year_months.each do |issuer, year_months_data|
    #         friendly_name = ServiceProvider.find_by(issuer: issuer).friendly_name
    #         year_months = year_months_data.keys.sort

    #         year_months.each do |year_month|
    #           iaa_results = by_iaa_and_year_month[ [iaa_key, year_month] ]
    #           if !iaa_results
    #             logger.warn(
    #               {
    #                 level: 'warning',
    #                 name: 'missing iaa_results',
    #                 iaa: iaa_key,
    #                 year_month: year_month,
    #               }.to_json,
    #             )
    #             next
    #           end

    #           issuer_results = year_months_data[year_month]
    #           year_month_start = Date.strptime(year_month, '%Y%m')
    #           iaa_start_date = Date.parse(iaa_results.first[:iaa_start_date])
    #           iaa_end_date = Date.parse(iaa_results.first[:iaa_end_date])

    #           partner_results = by_partner_results.find do |result|
    #             result[:year_month] == year_month && result[:issuers]&.include?(issuer)
    #           end || {}

    #           issuer_profile_age_results = by_issuer_profile_age_results.find do |result|
    #             result[:year_month] == year_month && result[:issuers]&.include?(issuer)
    #           end || {}

    #           csv << [
    #             iaa_key,
    #             partner_results[:partner],
    #             iaa_start_date,
    #             iaa_end_date,

    #             issuer,
    #             friendly_name,

    #             year_month,
    #             year_month_start.strftime('%B %Y'),

    #             # todo: these new lines are NOT being written out
    #             # additional values for IRS specifically
    #             # this line is what we need for Credentials authorized Requesting Agency
    #             extract(
    #               issuer_results, :total_auth_count,
    #               ial: 1
    #             ) + extract(issuer_results, :total_auth_count, ial: 2),
    #             # New identity verification/Credentials Authorized for Partner
    #             ((partner_results[:partner_ial2_new_unique_user_events_year1] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_year2] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_year3] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_year4] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_year5] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_year_greater_than_5] || 0) +
    #             (partner_results[:partner_ial2_new_unique_user_events_unknown] || 0)),

    #             # Existing identity verification/Credentials Authorized for Partner
    #             (((issuer_profile_age_results[:partner_ial2_unique_user_events_year1] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_year2] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_year3] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_year4] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_year5] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_year_greater_than_5] || 0)+ # rubocop:disable Layout/LineLength
    #             (issuer_profile_age_results[:partner_ial2_unique_user_events_unknown] || 0)) -
    #             ((issuer_profile_age_results[:partner_ial2_new_unique_user_events_year1] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year2] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year3] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year4] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year5] || 0) +
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_year_greater_than_5] || 0) + # rubocop:disable Layout/LineLength
    #             (issuer_profile_age_results[:partner_ial2_new_unique_user_events_unknown] || 0))),
    #           ]
    #         end
    #       end
    #     end
    #   end
    #   # rubocop:enable Metrics/BlockLength
    # end
    def combine_by_iaa_month(
      by_iaa_results:,
      by_issuer_results:,
      by_partner_results:,
      by_issuer_profile_age_results:
    )
      by_iaa_and_year_month = by_iaa_results.group_by { |result| [result[:key], result[:year_month]] }
    
      CSV.generate do |csv|
        csv << [
          'iaa_order_number',
          'partner',
          'iaa_start_date',
          'iaa_end_date',
          'year_month',
          'year_month_readable',
          'credentials_authorized_requesting_agency',
          'new_identity_verification_credentials_authorized_for_partner',
          'existing_identity_verification_credentials_authorized_for_partner',
        ]
    
        by_iaa_and_year_month.each do |(iaa_key, year_month), iaa_results|
          iaa_start_date = Date.parse(iaa_results.first[:iaa_start_date])
          iaa_end_date = Date.parse(iaa_results.first[:iaa_end_date])
          year_month_start = Date.strptime(year_month, '%Y%m')
    
          issuer_results = by_issuer_results.select { |r| r[:iaa] == iaa_key && r[:year_month] == year_month }
    
          total_auth = issuer_results.sum { |r| (r[:total_auth_count] if r[:ial] == 1 || r[:ial] == 2) || 0 }
    
          related_issuers = issuer_results.map { |r| r[:issuer] }.uniq
    
          partner_results = by_partner_results.select do |result|
            result[:year_month] == year_month && (result[:issuers] & related_issuers).any?
          end
    
          new_users = partner_results.sum do |r|
            %i[
              partner_ial2_new_unique_user_events_year1
              partner_ial2_new_unique_user_events_year2
              partner_ial2_new_unique_user_events_year3
              partner_ial2_new_unique_user_events_year4
              partner_ial2_new_unique_user_events_year5
              partner_ial2_new_unique_user_events_year_greater_than_5
              partner_ial2_new_unique_user_events_unknown
            ].sum { |key| r[key] || 0 }
          end
    
          existing_users = by_issuer_profile_age_results.select do |r|
            r[:year_month] == year_month && (r[:issuers] & related_issuers).any?
          end.sum do |r|
            total = %i[
              partner_ial2_unique_user_events_year1
              partner_ial2_unique_user_events_year2
              partner_ial2_unique_user_events_year3
              partner_ial2_unique_user_events_year4
              partner_ial2_unique_user_events_year5
              partner_ial2_unique_user_events_year_greater_than_5
              partner_ial2_unique_user_events_unknown
            ].sum { |key| r[key] || 0 }
    
            new = %i[
              partner_ial2_new_unique_user_events_year1
              partner_ial2_new_unique_user_events_year2
              partner_ial2_new_unique_user_events_year3
              partner_ial2_new_unique_user_events_year4
              partner_ial2_new_unique_user_events_year5
              partner_ial2_new_unique_user_events_year_greater_than_5
              partner_ial2_new_unique_user_events_unknown
            ].sum { |key| r[key] || 0 }
    
            total - new
          end
    
          csv << [
            iaa_key,
            partner_results.first&.[](:partner),
            iaa_start_date,
            iaa_end_date,
            year_month,
            year_month_start.strftime('%B %Y'),
            total_auth,
            new_users,
            existing_users,
          ]
        end
      end
    end




    #def issuers
    #  [*IdentityConfig.store.irs_credentials_issuers]
    #end

    def emails
      [*IdentityConfig.store.irs_credentials_emails]
    end

    # def emails
    #   emails = [*IdentityConfig.store.irs_monthly_cred_metrics_emails]
    #   if report_date.next_day.day == 1
    #     emails += IdentityConfig.store.team_all_login_emails
    #   end
    #   emails
    # end

    def upload_to_s3(report_body,report_date,  report_name: nil)
      _latest, path = generate_s3_paths(REPORT_NAME, 'csv', subname: report_name, now: report_date)
      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: csv_file(report_body),
          content_type: 'text/csv',
          bucket: bucket_name,
        )
      end
    end

    def csv_file(report_array)
      CSV.generate do |csv|
        report_array.each do |row|
          csv << row
        end
      end
    end

    def report_configs
      IdentityConfig.store.irs_monthly_cred_metrics
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
