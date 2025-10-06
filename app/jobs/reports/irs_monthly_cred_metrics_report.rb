# frozen_string_literal: true

module Reports
  class IrsMonthlyCredMetricsReport < BaseReport
    REPORT_NAME = 'irs_monthly_cred_metrics'

    attr_reader :report_date, :receiver

    def initialize(report_date = Time.zone.yesterday.end_of_day, receiver = :internal, *args,
                   **rest)
      @report_date = report_date
      @receiver = receiver.to_sym
      super(*args, **rest)
    end

    def partner_accounts
      partner_strings = [*IdentityConfig.store.irs_partner_strings].reject(&:blank?)
      IaaReportingHelper.partner_accounts.filter do |account|
        partner_strings.include?(account.partner)
      end
    end

    def iaas
      IaaReportingHelper.iaas.filter do |iaa|
        iaa.end_date > 90.days.ago && (iaa.issuers & issuers).any?
      end
    end

    def issuers
      [*IdentityConfig.store.irs_issuers].reject(&:blank?)
    end

    def email_addresses
      internal_emails = [*IdentityConfig.store.irs_credentials_emails].reject(&:blank?)
      irs_emails = [] # Need to add IRS email config

      case receiver
      when :internal then internal_emails
      when :both then (internal_emails + irs_emails)
      end
    end

    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],

        ['Monthly Active Users', 'Count',
         'The total number of unique users across all IAL levels
          that successfully signed into IRS applications'],

        ['New Users - IAL2 Year 1', 'Count',
         'The number of new unique IRS users who are in their first IdV proofing year
           and authenticate with the IRS.

           This count correlates with the billing report charges for Newly Billed
           IdV users (Year 1), Agreement-Level Count.'],

        ['New Users - IAL2 Year 2+', 'Count',
         'The number of new unique IRS users who are in their IdV proofing years 2 - 5
          and authenticate with the IRS.

          This count correlates with the billing report charges for Newly Billed
          IdV users (Years 2 - 5+), Agreement-Level Count.'],

        ['Total Auths', 'Count',
         'The total number of authentication events processed
         (including multiple events per users) across all IRS
         applications during the reporting period'],

        ['IAL2 Auths', 'Count',
         'The total number of **IAL2** authentication events processed
         (including multiple events per users) across all IRS
         applications during the reporting period'],
      ]
    end

    def overview_table
      [
        ['Report Timeframe', 'Report Generated', 'Issuers'],
        ["#{report_date.beginning_of_month} to #{report_date.end_of_month}", Time.zone.today.to_s,
         issuers],
      ]
    end

    def perform(perform_date = Time.zone.yesterday.end_of_day)
      reports = as_emailable_irs_report(
        date: perform_date,
      )

      reports.each do |report|
        _latest_path, path = generate_s3_paths(
          REPORT_NAME, 'csv',
          subname: report.filename,
          now: perform_date
        )

        content_type = Mime::Type.lookup_by_extension('csv').to_s
        report_csv = csv_file(report.table)
        _url = upload_file_to_s3_bucket(
          path: path, body: report_csv, content_type: content_type,
        )
      end

      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - IRS Monthly Credential Report NOT SENT'
        return false
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "IRS Monthly Credential Metrics - #{perform_date.to_date}",
        message: preamble,
        reports: reports,
        attachment_format: :csv,
      ).deliver_now
      report_data
    end

    def as_emailable_irs_report(date:)
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          table: definitions_table,
          filename: 'irs_monthly_cred_definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
          filename: 'irs_monthly_cred_overview',
        ),
        Reporting::EmailableReport.new(
          title: "IRS Monthly Credential Metrics #{date.strftime('%B %Y')}",
          table: report_data,
          filename: 'irs_monthly_cred_metrics',
        ),

      ]
    end

    def report_data
      @report_data ||= build_report_data
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

    def csv_file(report_array)
      CSV.generate do |csv|
        report_array.each do |row|
          csv << row
        end
      end
    end

    private

    def build_report_data
      parsed_invoice_data = CSV.parse(invoice_report_data, headers: true)

      report_year_month = report_date.strftime('%Y%m')
      data_row = parsed_invoice_data.filter do |row|
        row['year_month'] == report_year_month
      end

      headers = definitions_table.transpose[0]
      report_array =
        [
          # Headers row
          headers,
        ] + data_row.map do |invoice_report|
              # Data rows - extract values directly from CSV row
              ['Value',
               invoice_report['iaa_unique_users'].to_i, # Monthly Active Users
               invoice_report['partner_ial2_new_unique_user_events_year1'].to_i, # New IAL Year 1
               ial2_year_2_plus(invoice_report), # New IAL Year 2
               invoice_report['issuer_ial1_plus_2_total_auth_count'].to_i, # Total Auths
               invoice_report['issuer_ial2_total_auth_count'].to_i] # IAL2 Auths
            end
      return report_array.transpose
    end

    def invoice_report_data
      @invoice_report_data ||= begin
        # Delegate only the CSV building to the existing class
        invoice_reporter = CombinedInvoiceSupplementReportV2.new
        data = invoice_reporter.build_csv(iaas, partner_accounts)
        save_report(REPORT_NAME, data, extension: 'csv')
        data
      end
    end

    def ial2_year_2_plus(row)
      %w[
        partner_ial2_new_unique_user_events_year2
        partner_ial2_new_unique_user_events_year3
        partner_ial2_new_unique_user_events_year4
        partner_ial2_new_unique_user_events_year5
      ].sum { |key| row[key].to_i }
    end
  end
end
