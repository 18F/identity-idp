require 'rails_helper'

RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  subject(:report) { Reports::IrsMonthlyCredMetricsReport.new(report_date) }

  let(:name) { 'irs_monthly_cred_metrics' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs_monthly_cred_metrics/2021/2021-03-02.irs_monthly_cred_metrics'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/irs_monthly_cred_metrics.csv",
      "#{report_folder}/irs_monthly_cred_overview.csv",
      "#{report_folder}/irs_monthly_cred_definitions.csv",
    ]
  end
  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_daily_reports_emails) { ['mock_irs@example.com'] }

  before do
    # App config/environment
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return(mock_daily_reports_emails)

    # S3 stub
    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(IdentityConfig.store).to receive(:irs_credentials_emails)
      .and_return(mock_daily_reports_emails)
    
  end



  context 'the beginning of the month, it sends records for previous month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'returns a CSV with expected headers and rows from fake iaas data' do
      # Create a fake `iaas` object with a `.results` method
      fake_iaas = instance_double('IrsAttemptsApiLogCollection')
      fake_results = [
        { user_id: 1, success: true, count: 5 },
        { user_id: 2, success: false, count: 3 },
      ]

      allow(fake_iaas).to receive(:results).and_return(fake_results)

      csv_table = report.send(:build_csv, fake_iaas, nil ,report_date)

      expect(csv_table).to be_a(CSV::Table)

      # Check headers
      expect(csv_table.headers).to match_array([:user_id, :success, :count])

      # Check contents
      expect(csv_table.length).to eq(2)
      expect(csv_table[0][:user_id]).to eq(1)
      expect(csv_table[0][:success]).to eq(true)
      expect(csv_table[0][:count]).to eq(5)
    end

    it 'sends out a report to IRS' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: ['mock_irs@example.com'],
        subject: 'IRS Monthly Credential Metrics - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date)
    end
  end

  it 'does not send the report if no emails are configured' do
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return('')
    expect(ReportMailer).not_to receive(:tables_report)
    expect(report).not_to receive(:reports)
    report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    report.perform(report_date)
  end



  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'is valid HTML' do
      expect(preamble).to be_html_safe
      expect { Nokogiri::XML(preamble) { |c| c.strict } }.not_to raise_error
    end


    context 'in a non-prod environment' do
      let(:env) { 'staging' }
      it 'has an alert with the environment name' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)
        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include(env)
      end
    end

    

  end
end