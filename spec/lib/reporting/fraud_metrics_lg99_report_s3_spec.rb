require 'rails_helper'
require 'reporting/fraud_metrics_lg99_report_s3'

RSpec.describe Reporting::FraudMetricsLg99ReportFromS3 do
  let(:s3_bucket) { 'test-reports-bucket' }
  let(:s3_prefix) { 'monthly-reports/2025-11/' }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }

  subject(:consumer) do
    described_class.new(
      s3_bucket: s3_bucket,
      s3_prefix: s3_prefix,
      s3_client: s3_client,
    )
  end

  let(:lg99_csv_content) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users seeing LG-99,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  let(:suspended_csv_content) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users suspended,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days Creation to Suspension,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days Proofed to Suspension,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  let(:reinstated_csv_content) do
    <<~CSV
      Metric,Total,Range Start,Range End
      Unique users reinstated,0,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
      Average Days to Reinstatement,n/a,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
    CSV
  end

  before do
    s3_client.stub_responses(
      :get_object,
      ->(context) {
        key = context.params[:key]
        case key
        when "#{s3_prefix}lg99_metrics.csv"
          { body: StringIO.new(lg99_csv_content) }
        when "#{s3_prefix}suspended_metrics.csv"
          { body: StringIO.new(suspended_csv_content) }
        when "#{s3_prefix}reinstated_metrics.csv"
          { body: StringIO.new(reinstated_csv_content) }
        else
          'NoSuchKey'
        end
      },
    )
  end

  describe '#populate_report' do
    context 'when all metrics are zero or n/a' do
      it 'returns a report with zero counts and n/a averages' do
        report = consumer.populate_report

        expect(report.lg99_unique_users_count).to eq(0)
        expect(report.unique_suspended_users_count).to eq(0)
        expect(report.average_days_creation_to_suspension).to eq('n/a')
        expect(report.average_days_proofed_to_suspension).to eq('n/a')
        expect(report.unique_reinstated_users_count).to eq(0)
        expect(report.average_days_to_reinstatement).to eq('n/a')
      end

      it 'extracts the correct time range' do
        report = consumer.populate_report

        expect(report.time_range.begin).to eq(Time.parse('2025-11-01 00:00:00 UTC'))
        expect(report.time_range.end).to eq(Time.parse('2025-11-30 23:59:59 UTC'))
      end

      it 'returns the correct stats_month' do
        report = consumer.populate_report

        expect(report.stats_month).to eq('Nov-2025')
      end
    end

    context 'when metrics have non-zero integer values' do
      let(:lg99_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users seeing LG-99,42,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      let(:suspended_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users suspended,15,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days Creation to Suspension,12.3,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days Proofed to Suspension,5.7,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      let(:reinstated_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users reinstated,8,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days to Reinstatement,3.2,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      it 'returns a report with correct numeric values' do
        report = consumer.populate_report

        expect(report.lg99_unique_users_count).to eq(42)
        expect(report.unique_suspended_users_count).to eq(15)
        expect(report.average_days_creation_to_suspension).to eq(12.3)
        expect(report.average_days_proofed_to_suspension).to eq(5.7)
        expect(report.unique_reinstated_users_count).to eq(8)
        expect(report.average_days_to_reinstatement).to eq(3.2)
      end
    end

    context 'when metrics have a different month range' do
      let(:lg99_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users seeing LG-99,100,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
        CSV
      end

      let(:suspended_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users suspended,20,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
          Average Days Creation to Suspension,7.0,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
          Average Days Proofed to Suspension,2.5,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
        CSV
      end

      let(:reinstated_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users reinstated,5,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
          Average Days to Reinstatement,1.5,2025-12-01 00:00:00 UTC,2025-12-31 23:59:59 UTC
        CSV
      end

      it 'extracts the December time range' do
        report = consumer.populate_report

        expect(report.time_range.begin).to eq(Time.parse('2025-12-01 00:00:00 UTC'))
        expect(report.time_range.end).to eq(Time.parse('2025-12-31 23:59:59 UTC'))
        expect(report.stats_month).to eq('Dec-2025')
      end
    end

    context 'when S3 prefix is empty' do
      let(:s3_prefix) { '' }

      subject(:consumer) do
        described_class.new(
          s3_bucket: s3_bucket,
          s3_prefix: s3_prefix,
          s3_client: s3_client,
        )
      end

      before do
        s3_client.stub_responses(
          :get_object,
          ->(context) {
            key = context.params[:key]
            case key
            when 'lg99_metrics.csv'
              { body: StringIO.new(lg99_csv_content) }
            when 'suspended_metrics.csv'
              { body: StringIO.new(suspended_csv_content) }
            when 'reinstated_metrics.csv'
              { body: StringIO.new(reinstated_csv_content) }
            else
              'NoSuchKey'
            end
          },
        )
      end

      it 'fetches files without a prefix' do
        report = consumer.populate_report

        expect(report.lg99_unique_users_count).to eq(0)
        expect(report.unique_suspended_users_count).to eq(0)
        expect(report.unique_reinstated_users_count).to eq(0)
      end
    end

    context 'when a CSV file is missing from S3' do
      before do
        s3_client.stub_responses(
          :get_object,
          ->(context) {
            key = context.params[:key]
            case key
            when "#{s3_prefix}lg99_metrics.csv"
              'NoSuchKey'
            when "#{s3_prefix}suspended_metrics.csv"
              { body: StringIO.new(suspended_csv_content) }
            when "#{s3_prefix}reinstated_metrics.csv"
              { body: StringIO.new(reinstated_csv_content) }
            end
          },
        )
      end

      it 'raises an error from the S3 client' do
        expect { consumer.populate_report }.to raise_error(
          Aws::S3::Errors::NoSuchKey,
        )
      end
    end

    context 'when a required metric is missing from a CSV' do
      let(:suspended_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users suspended,10,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      it 'raises an error for the missing metric' do
        expect { consumer.populate_report }.to raise_error(
          RuntimeError,
          "Metric 'Average Days Creation to Suspension' not found in CSV data",
        )
      end
    end

    context 'when CSV has large numeric values' do
      let(:lg99_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users seeing LG-99,1000000,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      let(:suspended_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users suspended,500000,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days Creation to Suspension,365.5,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days Proofed to Suspension,180.9,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      let(:reinstated_csv_content) do
        <<~CSV
          Metric,Total,Range Start,Range End
          Unique users reinstated,250000,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
          Average Days to Reinstatement,90.1,2025-11-01 00:00:00 UTC,2025-11-30 23:59:59 UTC
        CSV
      end

      it 'handles large values correctly' do
        report = consumer.populate_report

        expect(report.lg99_unique_users_count).to eq(1_000_000)
        expect(report.unique_suspended_users_count).to eq(500_000)
        expect(report.average_days_creation_to_suspension).to eq(365.5)
        expect(report.average_days_proofed_to_suspension).to eq(180.9)
        expect(report.unique_reinstated_users_count).to eq(250_000)
        expect(report.average_days_to_reinstatement).to eq(90.1)
      end
    end
  end

  describe 'S3 key construction' do
    it 'constructs the correct S3 keys with a prefix' do
      expect(s3_client).to receive(:get_object).with(
        bucket: s3_bucket,
        key: "#{s3_prefix}lg99_metrics.csv",
      ).and_return(
        double(body: StringIO.new(lg99_csv_content)),
      )

      expect(s3_client).to receive(:get_object).with(
        bucket: s3_bucket,
        key: "#{s3_prefix}suspended_metrics.csv",
      ).and_return(
        double(body: StringIO.new(suspended_csv_content)),
      )

      expect(s3_client).to receive(:get_object).with(
        bucket: s3_bucket,
        key: "#{s3_prefix}reinstated_metrics.csv",
      ).and_return(
        double(body: StringIO.new(reinstated_csv_content)),
      )

      consumer.populate_report
    end
  end

  describe 'FILENAMES constant' do
    it 'contains the expected file mappings' do
      expect(described_class::FILENAMES).to eq(
        lg99: 'lg99_metrics.csv',
        suspended: 'suspended_metrics.csv',
        reinstated: 'reinstated_metrics.csv',
      )
    end
  end
end
