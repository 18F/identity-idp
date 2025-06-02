# frozen_string_literal: true

require 'csv'

module Reports
  class IrsMonthlyCredMetricsReport < BaseReport
    REPORT_NAME = 'irs_monthly_cred_metrics'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],
        [
          'Credentials authorized for Partner',
          'Count',
          'The total number of users (new and existing)
          that successfully signed into the applications. ' \
          'The combined count of the two rows below: "new identity
           verification + existing identity verification".',
        ],
        [
          'New identity verification/Credentials Authorized for Partner',
          'Count',
          'The number of users without existing IAL2 credentials
          who complete IAL2 IdV for the partner.',
        ],
        [
          'Existing identity verification/Credentials Authorized for Partner',
          'Count',
          'The existing users who are already IAL2 verified
          and added authentication with the IRS; ' \
          'count of users who share credentials with these applications.',
        ],
      ]
    end

    def overview_table(issuers)
      [
        ['Report Timeframe', 'Report Generated', 'Issuers'],
        ["#{report_date.beginning_of_month} to #{report_date.end_of_month}", Time.zone.today.to_s, issuers],
      ]
    end

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date
      issuers = IaaReportingHelper.partner_accounts.select do |pc|
        pc.partner == 'IRS'
      end.flat_map(&:issuers)
      IaaReportingHelper.iaas.filter { |x| x.end_date > 90.days.ago }

      iaas = IaaReportingHelper.iaas.filter do |iaa|
        iaa.end_date > 90.days.ago &&
          (iaa.issuers & issuers).any? # intersection: at least one issuer matches
      end
      csv = build_csv(iaas, IaaReportingHelper.partner_accounts, report_date)
      email_addresses = emails.select(&:present?)

      # Check if any emails are found
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - IRS Monthly Credential Report NOT SENT'
        return false
      end
      reports = as_emailable_irs_report(
        iaas: iaas,
        partner_accounts: IaaReportingHelper.partner_accounts, date: report_date,
        issuers: issuers
      )
      reports.each do |report|
        upload_to_s3(report.table, report_date, report_name: report.filename)
      end
      ReportMailer.tables_report(
        email: email_addresses,
        subject: "IRS Monthly Credential Metrics - #{date.to_date}",
        message: preamble,
        reports: reports,
        attachment_format: :csv,
      )
      csv
    end

    def as_emailable_irs_report(iaas:, partner_accounts:, date:, issuers:)
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          table: definitions_table,
          filename: 'irs_monthly_cred_definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table(issuers), 
          filename: 'irs_monthly_cred_overview',
        ),
        Reporting::EmailableReport.new(
          title: "IRS Monthly Credential Metrics #{date.strftime('%B %Y')}",
          table: CSV.parse(build_csv(iaas, partner_accounts, date)),
          filename: 'irs_monthly_cred_metrics',
        ),

      ]
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
        <p>
          For more information on how each of these metrics are calculated, take a look at our
          <a href="https://handbook.login.gov/articles/monthly-key-metrics-explainer.html">
          Monthly Key Metrics Report Explainer document</a>.
        </p>
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

    private

    def write_csv_header(csv)
      csv << [
        'Credentials Authorized',
        'New ID Verifications Authorized Credentials',
        'Existing Identity Verification Credentials',
      ]
    end

    def write_csv_row(csv:, iaa_key:, year_month:, iaa_results:, by_issuer_results:,
                      by_partner_results:, by_issuer_profile_age_results:)
      Date.parse(iaa_results.first[:iaa_start_date])
      Date.parse(iaa_results.first[:iaa_end_date])
      Date.strptime(year_month, '%Y%m')

      issuer_results = by_issuer_results.select do |r|
        r[:iaa] == iaa_key && r[:year_month] == year_month
      end

      total_auth = issuer_results.sum do |r|
        (r[:total_auth_count] if r[:ial] == 1 || r[:ial] == 2) || 0
      end

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
        total_auth,
        new_users,
        existing_users,
      ]
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
      CSV.generate do |csv|
        write_csv_header(csv)
        by_iaa_and_year_month.each do |(iaa_key, year_month), iaa_results|
          write_csv_row(
            csv: csv,
            iaa_key: iaa_key,
            year_month: year_month,
            iaa_results: iaa_results,
            by_issuer_results: by_issuer_results,
            by_partner_results: by_partner_results,
            by_issuer_profile_age_results: by_issuer_profile_age_results,
          )
        end
      end
    end

    def emails
      [*IdentityConfig.store.irs_credentials_emails]
    end

    def upload_to_s3(report_body, report_date, report_name: nil)
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

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
