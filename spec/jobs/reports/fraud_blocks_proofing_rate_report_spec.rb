require 'rails_helper'

RSpec.describe Reports::FraudBlocksProofingRateReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:time_range) { report_date.all_month }
  subject(:report) { Reports::FraudBlocksProofingRateReport.new(report_date) }

  let(:name) { 'fraud-blocks-proofing-rate-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    # help with this line to better understand it -------------------------------------------------
    'int/fraud-blocks-proofing-rate-report/2021/2021-03-02.fraud-blocks-proofing-rate-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/suspected_fraud_blocks_metrics.csv",
      "#{report_folder}/key_points_user_friction_metrics.csv",
      "#{report_folder}/successful_ipp.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end
  # help on these ----------------------------------------------------------------
  let(:mock_suspected_fraud_blocks_metrics_data) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Authentic Drivers License', 10, time_range.begin.to_s, time_range.end.to_s],
      ['Valid Drivers License #', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Facial Matching Check', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Identity Not Found', 10, time_range.begin.to_s, time_range.end.to_s],
      ['Address / Occupancy Match', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Social Security Number Match', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Date of Birth Match', 10, time_range.begin.to_s, time_range.end.to_s],
      ['Deceased Check', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Phone Account Ownership', 4, time_range.begin.to_s, time_range.end.to_s],
      ['Device and Behavior Fraud Signals', 4, time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  let(:mock_key_points_user_friction_metrics_data) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Document / selfie upload UX challenge', time_range.begin.to_s, time_range.end.to_s],
      ['Verification code not received', time_range.begin.to_s, time_range.end.to_s],
      ['API connection fails', time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  let(:mock_successful_ipp_data) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Successful IPP', 12000,  time_range.begin.to_s, time_range.end.to_s],
    ]
  end
  # help end --------------------------------------------------------------------

  let(:mock_test_auth_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:mock_test_auth_issuers) { ['issuer1'] }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(IdentityConfig.store).to receive(:fraud_blocks_proofing_rate_report_emails)
      .and_return(mock_test_auth_emails)

    allow(report.fraud_blocks_proofing_rate_report).to receive(
      :suspected_fraud_blocks_metrics_table,
    )
      .and_return(mock_suspected_fraud_blocks_metrics_data)

    allow(report.fraud_blocks_proofing_rate_report).to receive(
      :key_points_user_friction_metrics_table,
    )
      .and_return(mock_key_points_user_friction_metrics_data)

    allow(report.fraud_blocks_proofing_rate_report).to receive(:successful_ipp_table)
      .and_return(mock_successful_ipp_data)
  end

  it 'sends out a report to just to team data' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      email: anything,
      subject: 'Fraud Blocks and Proofing Rate Report - 2021-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :csv,
    ).and_call_original

    report.perform(report_date)
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:fraud_blocks_proofing_rate_report_emails).and_return('')

    expect(report).to_not receive(:reports)

    expect(ReportMailer).not_to receive(:tables_report)

    report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(subject).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    report.perform(report_date)
  end

  describe '#emails' do
    context 'on the first of the month' do
      let(:report_date) { Date.new(2021, 3, 1).prev_day }

      it 'emails the whole fraud team' do
        expected_array = mock_test_auth_emails

        expect(report.emails).to match_array(expected_array)
      end
    end

    context 'during the rest of the month' do
      let(:report_date) { Date.new(2021, 3, 2).prev_day }
      it 'only emails test_fraud_reports' do
        expect(report.emails).to match_array(
          mock_test_fraud_emails,
        )
      end
    end
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'has a blank preamble' do
      expect(preamble).to be_blank
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
