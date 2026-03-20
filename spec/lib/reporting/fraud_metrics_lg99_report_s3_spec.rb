# frozen_string_literal: true

require 'rails_helper'
require 'reporting/fraud_metrics_lg99_report_s3'

RSpec.describe Reporting::FraudMetricsLg99ReportS3 do
  let(:time_range) { Date.new(2025, 11, 1).in_time_zone('UTC').all_month }
  let(:bucket_name) { 'login-gov-dw-reports-487317109730-us-west-2' }
  let(:s3_path_prefix) { 'sliang/idp/fraud-metrics-report/2025/2025-11-01.fraud-metrics-report' }

  let(:lg99_metrics_csv) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users seeing LG-99,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  let(:suspended_metrics_csv) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users suspended,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days Creation to Suspension,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days Proofed to Suspension,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  let(:reinstated_metrics_csv) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users reinstated,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days to Reinstatement,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    allow_any_instance_of(JobHelpers::S3Helper).to receive(:s3_client).and_return(s3_client)
    s3_client.stub_responses(
      :get_object,
      lambda do |context|
        case context.params[:key]
        when "#{s3_path_prefix}/lg99_metrics.csv"
          { body: StringIO.new(lg99_metrics_csv) }
        when "#{s3_path_prefix}/suspended_metrics.csv"
          { body: StringIO.new(suspended_metrics_csv) }
        when "#{s3_path_prefix}/reinstated_metrics.csv"
          { body: StringIO.new(reinstated_metrics_csv) }
        else
          'NoSuchKey'
        end
      end,
    )
  end

  subject(:report) do
    described_class.new(
      time_range: time_range,
      bucket_name: bucket_name,
      s3_path_prefix: s3_path_prefix,
    )
  end

  describe 'initialization' do
    context 'when neither report_date nor s3_path_prefix is provided' do
      it 'raises an ArgumentError' do
        expect do
          described_class.new(time_range: time_range, bucket_name: bucket_name)
        end.to raise_error(
          ArgumentError,
          /report_date.*s3_path_prefix|s3_path_prefix.*report_date/,
        )
      end
    end

    context 'when report_date is provided without s3_path_prefix' do
      let(:report_date) { Date.new(2026, 3, 15) }
      let(:derived_prefix) do
        'sliang/idp/fraud-metrics-report/2026/2026-03-15.fraud-metrics-report'
      end

      before do
        s3_client.stub_responses(
          :get_object,
          lambda do |context|
            case context.params[:key]
            when "#{derived_prefix}/lg99_metrics.csv"
              { body: StringIO.new(lg99_metrics_csv) }
            when "#{derived_prefix}/suspended_metrics.csv"
              { body: StringIO.new(suspended_metrics_csv) }
            when "#{derived_prefix}/reinstated_metrics.csv"
              { body: StringIO.new(reinstated_metrics_csv) }
            else
              'NoSuchKey'
            end
          end,
        )
      end

      it 'derives the correct s3_path_prefix from report_date' do
        report_with_date = described_class.new(
          time_range: time_range,
          bucket_name: bucket_name,
          env: 'sliang',
          report_date: report_date,
        )
        report_with_date.lg99_metrics_table

        expect(s3_client.api_requests.first).to include(
          operation_name: :get_object,
          params: hash_including(
            bucket: bucket_name,
            key: "#{derived_prefix}/lg99_metrics.csv",
          ),
        )
      end
    end

    context 'when s3_path_prefix is explicitly provided' do
      it 'uses the given s3_path_prefix (backward compatibility)' do
        report.lg99_metrics_table

        expect(s3_client.api_requests.first).to include(
          operation_name: :get_object,
          params: hash_including(
            bucket: bucket_name,
            key: "#{s3_path_prefix}/lg99_metrics.csv",
          ),
        )
      end
    end
  end

  describe '#lg99_metrics_table' do
    let(:expected_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users seeing LG-99', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
      ]
    end

    it 'returns the parsed lg99 metrics CSV data' do
      expect(report.lg99_metrics_table).to eq(expected_table)
    end
  end

  describe '#reinstated_metrics_table' do
    let(:expected_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users reinstated', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
        [
          'Average Days to Reinstatement', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
      ]
    end

    it 'returns the parsed reinstated metrics CSV data' do
      expect(report.reinstated_metrics_table).to eq(expected_table)
    end
  end

  describe '#suspended_metrics_table' do
    let(:expected_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users suspended', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
        [
          'Average Days Creation to Suspension', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
        [
          'Average Days Proofed to Suspension', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
      ]
    end

    it 'returns the parsed suspended metrics CSV data' do
      expect(report.suspended_metrics_table).to eq(expected_table)
    end
  end

  describe '#stats_month' do
    it 'returns a formatted month-year string' do
      expect(report.stats_month).to eq('Nov-2025')
    end
  end

  describe '#as_emailable_reports' do
    let(:expected_lg99_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users seeing LG-99', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
      ]
    end

    let(:expected_suspended_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users suspended', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
        [
          'Average Days Creation to Suspension', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
        [
          'Average Days Proofed to Suspension', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
      ]
    end

    let(:expected_reinstated_table) do
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users reinstated', '0', '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'],
        [
          'Average Days to Reinstatement', 'n/a',
          '2025-11-01 00:00:00 UTC', '2025-11-30 23:59:59 UTC'
        ],
      ]
    end

    let(:expected_reports) do
      [
        Reporting::EmailableReport.new(
          title: 'Monthly LG-99 Metrics Nov-2025',
          filename: 'lg99_metrics',
          table: expected_lg99_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Monthly Suspended User Metrics Nov-2025',
          filename: 'suspended_metrics',
          table: expected_suspended_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Monthly Reinstated User Metrics Nov-2025',
          filename: 'reinstated_metrics',
          table: expected_reinstated_table,
        ),
      ]
    end

    it 'returns expected emailable reports' do
      expect(report.as_emailable_reports).to eq(expected_reports)
    end
  end

  describe '#csv_data_for' do
    it 'caches results for subsequent calls' do
      result1 = report.csv_data_for('lg99_metrics')
      result2 = report.csv_data_for('lg99_metrics')
      expect(result1).to equal(result2)
    end

    context 'when the S3 key does not exist' do
      it 'raises an error' do
        expect { report.csv_data_for('nonexistent_report') }.to raise_error(
          Aws::S3::Errors::NoSuchKey,
        )
      end
    end
  end

  describe 'S3 key construction' do
    it 'fetches from the correct bucket and key path' do
      report.lg99_metrics_table

      expect(s3_client.api_requests.first).to include(
        operation_name: :get_object,
        params: hash_including(
          bucket: bucket_name,
          key: "#{s3_path_prefix}/lg99_metrics.csv",
        ),
      )
    end
  end

  context 'with non-zero metric values' do
    let(:lg99_metrics_csv) do
      <<~CSV
        Metric,Total,Range Start,Range End
        Unique users seeing LG-99,42,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      CSV
    end

    let(:suspended_metrics_csv) do
      <<~CSV
        Metric,Total,Range Start,Range End
        Unique users suspended,10,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        Average Days Creation to Suspension,3.5,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        Average Days Proofed to Suspension,2.1,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      CSV
    end

    let(:reinstated_metrics_csv) do
      <<~CSV
        Metric,Total,Range Start,Range End
        Unique users reinstated,5,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        Average Days to Reinstatement,7.2,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      CSV
    end

    it 'returns tables with the correct non-zero values' do
      expect(report.lg99_metrics_table[1][1]).to eq('42')
      expect(report.suspended_metrics_table[1][1]).to eq('10')
      expect(report.suspended_metrics_table[2][1]).to eq('3.5')
      expect(report.suspended_metrics_table[3][1]).to eq('2.1')
      expect(report.reinstated_metrics_table[1][1]).to eq('5')
      expect(report.reinstated_metrics_table[2][1]).to eq('7.2')
    end
  end
end
