# frozen_string_literal: true

module Reports
  class NewTestTheMonthlyIrsReport < CombinedInvoiceSupplementReportV2
    REPORT_NAME = 'irs_monthly_cred_metrics'

    attr_reader :report_date

    def partner_accounts
      partner = config&.fetch('partner', nil)

      return [] unless partner

      IaaReportingHelper.partner_accounts.filter do |x|
        x.partner == partner
      end
    end

    def iaas
      IaaReportingHelper.iaas.filter do |x|
        x.end_date > 90.days.ago && (x.issuers & issuers).any?
      end
    end

    def issuers
      issuers = config&.fetch('issuers', nil)
      return [] unless issuers
    end

    def irs_monthly_cred
      @irs_monthly_cred || Reports::IrsMonthlyCredMetricsReport.new(@report_date)
    end

    def email_addresses
      email_addresses = config&.fetch('emails', nil)

      return [] unless email_addresses
    end

    def config
      IdentityConfig.store.irs_credential_tenure_report_config
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
          'The number of users who are in their first IdV proofing year
           and authenticate with the IRS.
           This count correlates with the billing report charges for Newly Billed
           IdV users (Year 1), Agreement-Level Count.',
        ],
        [
          'Existing identity verification/Credentials Authorized for Partner',
          'Count',
          'The number of users who are in IdV proofing years 2 - 5 and authenticate with the IRS.
          This count correlates with the billing report charges for Newly Billed
          IdV users (Years 2 - 5+), Agreement-Level Count. ' \
          'count of users who share credentials with these applications.',
        ],
      ]
    end

    def overview_table
      [
        ['Report Timeframe', 'Report Generated', 'Issuers'],
        ["#{report_date.beginning_of_month} to #{report_date.end_of_month}", Time.zone.today.to_s,
         issuers],
      ]
    end

    def perform(report_date = Time.zone.yesterday.end_of_day)
      @report_date = report_date

      # Exclude IAAs that ended more than 90 days ago
      csv_data = build_csv(iaas, partner_accounts)
      save_report(REPORT_NAME, csv_data, extension: 'csv')

      parsed_csv = CSV.parse(csv_data, headers: true)

      # Go straight to array of arrays format
      selected_data = [
        # Headers row
        ['Month', 'IAL2 Auths', 'IAL2 Year 1', 'IAL2 Year 2+', 'Monthly Active Users',
         'Total Auths'],
      ] + parsed_csv.map do |row|
        # Data rows - extract values directly from CSV row
        [
          row['year_month_readable'],
          row['issuer_ial2_total_auth_count'].to_i,
          row['partner_ial2_new_unique_user_events_year1'].to_i,
          (row['partner_ial2_new_unique_user_events_year2'].to_i +
           row['partner_ial2_new_unique_user_events_year3'].to_i +
           row['partner_ial2_new_unique_user_events_year4'].to_i +
           row['partner_ial2_new_unique_user_events_year5'].to_i),
          row['iaa_unique_users'].to_i,
          row['issuer_ial1_plus_2_total_auth_count'].to_i,
        ]
      end

      reports = as_emailable_irs_report(
        date: report_date,
        csv: selected_data,
      )

      reports.each do |report|
        _latest_path, path = generate_s3_paths(report.filename, 'csv')
        content_type = Mime::Type.lookup_by_extension('csv').to_s
        _url = upload_file_to_s3_bucket(path: path, body: report.table, content_type: content_type)
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "TEST - IRS Monthly Credential Metrics - #{report_date.to_date}",
        message: irs_monthly_cred.preamble,
        reports: reports,
        attachment_format: :csv,
      ).deliver_now
      selected_data
    end

    def as_emailable_irs_report(date:, csv:)
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
          table: csv,
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

    def csv_file(report_array)
      CSV.generate do |csv|
        report_array.each do |row|
          csv << row
        end
      end
    end
  end
end
