# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsS3Report do
  let(:report_date) { Date.new(2026, 3, 2).in_time_zone('UTC').end_of_day }
  subject(:report) { described_class.new(report_date) }

  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/MonthlyKeyMetricsIdvS3Report/2026/2026-03-02.MonthlyKeyMetricsIdvS3Report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/active_users_count.csv",
      "#{report_folder}/total_user_count.csv",
      "#{report_folder}/condensed_idv.csv",
      "#{report_folder}/proofing_rate_metrics.csv",
      "#{report_folder}/account_deletion_rate.csv",
      "#{report_folder}/account_reuse.csv",
      "#{report_folder}/agency_and_sp_counts.csv",
      "#{report_folder}/active_users_count_apg.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_all_login_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:mock_daily_reports_emails) { ['mock_agnes@example.com', 'mock_daily@example.com'] }

  let(:condensed_idv_table) { [['Metric', 'Mar 2026'], ['IDV started', 100]] }
  let(:proofing_rate_table) { [['Metric', 'Trailing 30d'], ['IDV Started', 100]] }

  let(:condensed_idv_emailable_report) do
    Reporting::EmailableReport.new(
      title: 'Proofing Rate Metrics',
      subtitle: 'Condensed (NEW)',
      float_as_percent: true,
      precision: 2,
      table: condensed_idv_table,
      filename: 'condensed_idv',
    )
  end

  let(:proofing_rate_emailable_report) do
    Reporting::EmailableReport.new(
      subtitle: 'Detail',
      float_as_percent: true,
      precision: 2,
      table: proofing_rate_table,
      filename: 'proofing_rate_metrics',
    )
  end

  let(:idv_s3_report) do
    instance_double(
      Reporting::MonthlyKeyMetricsIdvS3Report,
      csv_file_names: %w[condensed_idv proofing_rate_metrics],
      condensed_idv_emailable_report: condensed_idv_emailable_report,
      proofing_rate_emailable_report: proofing_rate_emailable_report,
    )
  end

  # All IDV files exist and are fresh by default.
  let(:fresh_last_modified) { 1.day.ago }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:s3_data_warehouse_replica_bucket_prefix)
      .and_return('data-warehouse-bucket')

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(report).to receive(:idv_s3_report).and_return(idv_s3_report)
    allow(idv_s3_report).to receive(:get_file_last_modified)
      .and_return(fresh_last_modified)

    allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
      .and_return(mock_daily_reports_emails)
    allow(IdentityConfig.store).to receive(:team_all_login_emails)
      .and_return(mock_all_login_emails)
  end

  it 'sends out a report to just team agnes' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      to: anything,
      subject: 'Monthly Key Metrics Report NEW - 2026-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :xlsx,
    ).and_call_original

    report.perform(report_date)
  end

  context 'when queued from the first of the month' do
    let(:report_date) { Date.new(2026, 3, 1).prev_day }

    it 'sends out a report to everybody' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: anything,
        subject: 'Monthly Key Metrics Report NEW - 2026-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :xlsx,
      ).and_call_original

      report.perform(report_date)
    end
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')

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

  describe 'IDV S3 report availability' do
    context 'when an IDV file is missing' do
      before do
        allow(idv_s3_report).to receive(:get_file_last_modified)
          .with('condensed_idv')
          .and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'Key not found'))
      end

      it 'aborts the whole report and does not email or upload' do
        expect(report).to_not receive(:reports)
        expect(report).to_not receive(:upload_to_s3)
        expect(ReportMailer).to_not receive(:tables_report)

        expect(report.perform(report_date)).to eq(false)
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).at_least(:once)

        report.perform(report_date)
      end
    end

    context 'when an IDV file is stale' do
      before do
        allow(idv_s3_report).to receive(:get_file_last_modified)
          .with('condensed_idv')
          .and_return((described_class::MAX_FILE_AGE_DAYS + 1).days.ago)
        allow(idv_s3_report).to receive(:get_file_last_modified)
          .with('proofing_rate_metrics')
          .and_return(fresh_last_modified)
      end

      it 'aborts the whole report' do
        expect(report).to_not receive(:reports)
        expect(ReportMailer).to_not receive(:tables_report)

        expect(report.perform(report_date)).to eq(false)
      end
    end

    context 'when the data warehouse bucket name is blank' do
      before do
        allow(IdentityConfig.store).to receive(:s3_data_warehouse_replica_bucket_prefix)
          .and_return('')
        allow(Identity::Hostdata).to receive(:aws_account_id).and_return('')
        allow(Identity::Hostdata).to receive(:aws_region).and_return('')
      end

      it 'aborts when bucket resolves to blank' do
        # data_warehouse_bucket_name builds from prefix-account-region; force fully blank
        allow(report).to receive(:data_warehouse_bucket_name).and_return('')

        expect(ReportMailer).to_not receive(:tables_report)
        expect(report.perform(report_date)).to eq(false)
      end
    end

    context 'when all IDV files exist and are fresh' do
      it 'proceeds to send the report' do
        expect(ReportMailer).to receive(:tables_report).and_call_original

        report.perform(report_date)
      end
    end
  end

  describe '#reports' do
    it 'includes the IDV reports sourced from the S3 reader in the correct positions' do
      reports = report.reports

      expect(reports[2]).to eq(condensed_idv_emailable_report)
      expect(reports[3]).to eq(proofing_rate_emailable_report)
      expect(reports.size).to eq(8)
    end
  end

  describe '#idv_s3_path' do
    before do
      # Use the real method (un-stub idv_s3_report side effects don't matter here).
      allow(report).to receive(:generate_base_s3_path)
        .with(directory: 'idp')
        .and_return('int/')
    end

    it 'builds the prefix matching reporting-rails paths_for' do
      expect(report.idv_s3_path).to eq(
        'int/MonthlyKeyMetricsIdvS3Report/2026/03/20260302_monthly',
      )
    end
  end

  describe '#emails' do
    context 'on the first of the month' do
      let(:report_date) { Date.new(2026, 3, 1).prev_day }

      it 'emails the whole login team' do
        expected_array = mock_daily_reports_emails + mock_all_login_emails
        expect(report.emails).to match_array(expected_array)
      end
    end

    context 'during the rest of the month' do
      let(:report_date) { Date.new(2026, 3, 2).prev_day }

      it 'only emails team_daily_reports' do
        expect(report.emails).to match_array(mock_daily_reports_emails)
      end
    end
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'has a preamble that is valid HTML' do
      expect(preamble).to be_html_safe
      expect { Nokogiri::XML(preamble) { |config| config.strict } }.to_not raise_error
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
