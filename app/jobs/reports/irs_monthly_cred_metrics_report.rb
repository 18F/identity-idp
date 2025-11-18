# frozen_string_literal: true

module Reports
  class IrsMonthlyCredMetricsReport < BaseReport
    REPORT_NAME = 'irs_monthly_cred_metrics'

    attr_reader :report_date, :report_receiver

    def initialize(init_date = Time.zone.yesterday.end_of_day, init_receiver = :internal, *args,
                   **rest)
      @report_date = init_date
      @report_receiver = init_receiver.to_sym
      super(init_date, init_receiver, *args, **rest)
    end

    def partner_strings
      [*IdentityConfig.store.irs_partner_strings].reject(&:blank?)
    end

    def partner_accounts
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
      internal_emails = [*IdentityConfig.store.team_daily_reports_emails]
      irs_emails = [*IdentityConfig.store.irs_credentials_emails]
      case report_receiver
      when :internal then internal_emails
      when :both then (internal_emails + irs_emails)
      end
    end

    # rubocop:disable Layout/LineLength
    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],

        ['Monthly active users', 'Count',
         'The total number of unique users across all IAL levels
          that successfully signed into the partner\'s applications'],

        ['Credentials authorized for partner', 'Count',
         'The total number of users (new and existing)
         that successfully signed into the partner\'s applications'],

        ['New identity verification credentials authorized for partner', 'Count',
         'The number of new unique users who go through the proofing process through a partner\'s request.'],

        ['Existing identity verification credentials authorized for partner', 'Count',
         'The number of new unique users who authenticated with existing identity verification credentials to the partner.'],

        ['Total authentications', 'Count',
         'Total number of billable sign-ins at any IAL level in the reporting period'],
      ]
    end
    # rubocop:enable Layout/LineLength

    def overview_table
      [
        ['Report Timeframe', 'Report Generated', 'Issuers'],
        ["#{report_date.beginning_of_month} to #{report_date.end_of_month}", Time.zone.today.to_s,
         issuers.join(', ')],
      ]
    end

    def perform(perform_date = Time.zone.yesterday.end_of_day, perform_receiver = :internal)
      @report_receiver = perform_receiver.to_sym
      @report_date = perform_date
      reports = as_emailable_partner_report(
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

      emails = email_addresses.select(&:present?)
      if emails.empty?
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
      [issuer_report_data, partner_report_data]
    end

    def as_emailable_partner_report(date:)
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
          table: issuer_report_data,
          filename: 'irs_monthly_cred_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Treasury Partner Monthly Credential Metrics #{date.strftime('%B %Y')}",
          table: partner_report_data,
          filename: 'treasury_monthly_cred_metrics',
        ),

      ]
    end

    def issuer_report_data
      @issuer_report_data ||= build_issuer_data
    end

    def partner_report_data
      @partner_report_data ||= build_partner_data
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

    def build_issuer_data
      invoice_data_csv = CSV.parse(invoice_report_data, headers: true)

      issuer_invoice_data = invoice_data_csv.select do |r|
        issuers.include?(r['issuer'])
      end

      parsed_invoice_data = CSV::Table.new(
        issuer_invoice_data,
        headers: invoice_data_csv.headers,
      )

      report_year_month = report_date.strftime('%Y%m')
      data_array = parsed_invoice_data.filter do |row|
        row['year_month'] == report_year_month
      end

      headers = definitions_table.transpose[0]
      headers[0] = 'Issuer'

      # rubocop:disable Layout/LineLength
      report_array =
        [
          # Headers row
          headers,
        ] + data_array.map do |invoice_report|
              # Data rows - extract values directly from CSV row
              [invoice_report['issuer'],
               invoice_report['issuer_unique_users'].to_i, # Monthly Active Users
               ial2_new_unique_all(invoice_report, :issuer), # Credentials Authorized
               invoice_report['issuer_ial2_new_unique_user_events_year1_upfront'].to_i, # New identity verification credentials authorized
               ial2_existing_credentials(invoice_report, :issuer), # Existing identity verification credentials authorized
               invoice_report['issuer_ial1_plus_2_total_auth_count'].to_i] # Total Auths
            end
      return report_array
      # rubocop:enable Layout/LineLength
    end

    def build_partner_data
      invoice_data_csv = CSV.parse(invoice_report_data, headers: true)

      partner_invoice_data = invoice_data_csv.select do |r|
        partner_strings.include?(r['partner'])
      end

      parsed_invoice_data = CSV::Table.new(
        partner_invoice_data,
        headers: invoice_data_csv.headers,
      )

      report_year_month = report_date.strftime('%Y%m')
      data_array = parsed_invoice_data.filter do |row|
        row['year_month'] == report_year_month
      end

      data_row = data_array.first

      headers_raw = definitions_table.transpose[0]
      headers_raw[0] = data_row['partner']

      headers = headers_raw.values_at(0, 2, 3, 4)

      # rubocop:disable Layout/LineLength
      report_array =
        [
          # Headers row
          headers,
          # Data row - wrap in array to match CSV structure
          [
            'Values',
            ial2_new_unique_all(data_row, :partner), # Credentials Authorized
            data_row['partner_ial2_new_unique_user_events_year1_upfront'].to_i, # New identity verification credentials authorized
            ial2_existing_credentials(data_row, :partner), # Existing identity verification credentials authorized
          ],
        ]
      return report_array.transpose
      # rubocop:enable Layout/LineLength
    end

    def invoice_report_data
      @invoice_report_data ||= begin
        # Delegate only the CSV building to the existing class
        invoice_reporter = CombinedInvoiceSupplementReportV2.new
        data = invoice_reporter.build_csv(iaas, partner_accounts)
        save_report(REPORT_NAME + '_raw', data, extension: 'csv')
        data
      end
    end

    def ial2_existing_credentials(row, report_type)
      case report_type
      when :partner
        %w[
          partner_ial2_new_unique_user_events_year1_existing
          partner_ial2_new_unique_user_events_year2
          partner_ial2_new_unique_user_events_year3
          partner_ial2_new_unique_user_events_year4
          partner_ial2_new_unique_user_events_year5
        ].sum { |key| row[key].to_i }

      when :issuer

        %w[
          issuer_ial2_new_unique_user_events_year1_existing
          issuer_ial2_new_unique_user_events_year2
          issuer_ial2_new_unique_user_events_year3
          issuer_ial2_new_unique_user_events_year4
          issuer_ial2_new_unique_user_events_year5
        ].sum { |key| row[key].to_i }
      end
    end

    def ial2_new_unique_all(row, report_type)
      case report_type
      when :partner
        %w[
          partner_ial2_new_unique_user_events_year1_upfront
          partner_ial2_new_unique_user_events_year1_existing
          partner_ial2_new_unique_user_events_year2
          partner_ial2_new_unique_user_events_year3
          partner_ial2_new_unique_user_events_year4
          partner_ial2_new_unique_user_events_year5
        ].sum { |key| row[key].to_i }
      when :issuer
        %w[
          issuer_ial2_new_unique_user_events_year1_upfront
          issuer_ial2_new_unique_user_events_year1_existing
          issuer_ial2_new_unique_user_events_year2
          issuer_ial2_new_unique_user_events_year3
          issuer_ial2_new_unique_user_events_year4
          issuer_ial2_new_unique_user_events_year5
        ].sum { |key| row[key].to_i }

      end
    end
  end
end
