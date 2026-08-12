# frozen_string_literal: true

require 'rails_helper'
require 'reporting/monthly_key_metrics_idv_s3_report'

RSpec.describe Reporting::MonthlyKeyMetricsIdvS3Report do
  let(:bucket_name) { 'test-bucket' }
  let(:custom_s3_path) { 'idp/MonthlyKeyMetricsIdvS3Report/2021/03/20210302_monthly' }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_helper) { instance_double(JobHelpers::S3Helper) }

  let(:report_reader) do
    described_class.new(
      bucket_name: bucket_name,
      custom_s3_path: custom_s3_path,
    )
  end

  before do
    allow(JobHelpers::S3Helper).to receive(:new).and_return(s3_helper)
    allow(s3_helper).to receive(:s3_client).and_return(s3_client)
  end

  describe '#initialize' do
    it 'sets the required attributes' do
      expect(report_reader.bucket_name).to eq(bucket_name)
      expect(report_reader.s3_path).to eq(custom_s3_path)
    end
  end

  describe '#csv_file_names' do
    it 'returns the expected file names' do
      expect(report_reader.csv_file_names).to eq(
        %w[condensed_idv proofing_rate_metrics],
      )
    end
  end

  describe '#csv_data_for' do
    let(:csv_content) { "Metric,Trailing 30d\nIDV Started,100\nBlanket Proofing Rate,0.8534" }
    let(:s3_response) do
      instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new(csv_content))
    end

    before do
      allow(s3_client).to receive(:get_object).and_return(s3_response)
    end

    it 'fetches CSV from the correct key' do
      report_reader.csv_data_for('proofing_rate_metrics')

      expect(s3_client).to have_received(:get_object).with(
        bucket: bucket_name,
        key: "#{custom_s3_path}_proofing_rate_metrics.csv",
      )
    end

    it 'coerces integer-looking cells to Integer' do
      result = report_reader.csv_data_for('proofing_rate_metrics')

      idv_started_row = result.find { |row| row.first == 'IDV Started' }
      expect(idv_started_row.last).to eq(100)
      expect(idv_started_row.last).to be_a(Integer)
    end

    it 'coerces decimal-looking cells to Float (so float_as_percent works)' do
      result = report_reader.csv_data_for('proofing_rate_metrics')

      rate_row = result.find { |row| row.first == 'Blanket Proofing Rate' }
      expect(rate_row.last).to eq(0.8534)
      expect(rate_row.last).to be_a(Float)
    end

    it 'leaves non-numeric cells (labels/headers) as Strings' do
      result = report_reader.csv_data_for('proofing_rate_metrics')

      expect(result.first).to eq(['Metric', 'Trailing 30d'])
      expect(result.first).to all(be_a(String))
    end

    it 'memoizes the result' do
      report_reader.csv_data_for('condensed_idv')
      report_reader.csv_data_for('condensed_idv')

      expect(s3_client).to have_received(:get_object).once
    end

    it 'fetches different reports independently' do
      report_reader.csv_data_for('condensed_idv')
      report_reader.csv_data_for('proofing_rate_metrics')

      expect(s3_client).to have_received(:get_object).twice
    end

    context 'when S3 file does not exist' do
      before do
        allow(s3_client).to receive(:get_object).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, 'Key not found'),
        )
      end

      it 'logs an error and re-raises' do
        expect(Rails.logger).to receive(:error)
          .with(/Unexpected failure reading CSV file from S3/)

        expect { report_reader.csv_data_for('condensed_idv') }
          .to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end
  end

  describe 'coerce_cell edge cases' do
    let(:csv_content) do
      "Label,Value\nEmpty,\nNegative,-5\nNegativeFloat"\
      ",-0.25\nLeadingDot,.5\nDate,2026-05-31\nMixed,12abc"
    end
    let(:s3_response) do
      instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new(csv_content))
    end

    before do
      allow(s3_client).to receive(:get_object).and_return(s3_response)
    end

    it 'handles empties, negatives, decimals, dates, and mixed strings correctly' do
      rows = report_reader.csv_data_for('condensed_idv').to_h { |r| [r.first, r.last] }

      expect(rows['Empty']).to be_nil # CSV.parse yields nil for trailing empty cell
      expect(rows['Negative']).to eq(-5).and be_a(Integer)
      expect(rows['NegativeFloat']).to eq(-0.25).and be_a(Float)
      expect(rows['LeadingDot']).to eq(0.5).and be_a(Float)
      expect(rows['Date']).to eq('2026-05-31') # left as String, not coerced
      expect(rows['Mixed']).to eq('12abc') # left as String
    end
  end

  describe '#get_file_last_modified' do
    let(:last_modified) { Time.zone.now - 1.day }
    let(:head_response) do
      instance_double(Aws::S3::Types::HeadObjectOutput, last_modified: last_modified)
    end

    before do
      allow(s3_client).to receive(:head_object).and_return(head_response)
    end

    it 'returns the last modified time for the correct key' do
      result = report_reader.get_file_last_modified('condensed_idv')

      expect(s3_client).to have_received(:head_object).with(
        bucket: bucket_name,
        key: "#{custom_s3_path}_condensed_idv.csv",
      )
      expect(result).to eq(last_modified)
    end

    context 'when file does not exist' do
      before do
        allow(s3_client).to receive(:head_object).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, 'Key not found'),
        )
      end

      it 'raises NoSuchKey' do
        expect { report_reader.get_file_last_modified('condensed_idv') }
          .to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end
  end

  describe 'emailable reports' do
    let(:table) { [['Metric', 'Trailing 30d'], ['IDV Started', 100]] }

    before do
      allow(report_reader).to receive(:condensed_idv_table).and_return(table)
      allow(report_reader).to receive(:proofing_rate_table).and_return(table)
    end

    describe '#as_emailable_reports' do
      it 'returns both EmailableReports in order' do
        reports = report_reader.as_emailable_reports

        expect(reports).to all(be_a(Reporting::EmailableReport))
        expect(reports.size).to eq(2)
        expect(reports[0].filename).to eq('condensed_idv')
        expect(reports[1].filename).to eq('proofing_rate_metrics')
      end
    end

    describe '#condensed_idv_emailable_report' do
      subject(:report) { report_reader.condensed_idv_emailable_report }

      it 'mirrors MonthlyIdvReport formatting' do
        expect(report.title).to eq('Proofing Rate Metrics')
        expect(report.subtitle).to eq('Condensed (NEW)')
        expect(report.float_as_percent).to eq(true)
        expect(report.precision).to eq(2)
        expect(report.filename).to eq('condensed_idv')
        expect(report.table).to eq(table)
      end
    end

    describe '#proofing_rate_emailable_report' do
      subject(:report) { report_reader.proofing_rate_emailable_report }

      it 'mirrors ProofingRateReport formatting' do
        expect(report.subtitle).to eq('Detail')
        expect(report.float_as_percent).to eq(true)
        expect(report.precision).to eq(2)
        expect(report.filename).to eq('proofing_rate_metrics')
        expect(report.table).to eq(table)
      end
    end
  end

  describe 'table methods' do
    let(:csv_data) { [['header'], ['data']] }

    before do
      allow(report_reader).to receive(:csv_data_for).and_return(csv_data)
    end

    it '#condensed_idv_table reads the condensed_idv file' do
      expect(report_reader.condensed_idv_table).to eq(csv_data)
      expect(report_reader).to have_received(:csv_data_for).with('condensed_idv')
    end

    it '#proofing_rate_table reads the proofing_rate_metrics file' do
      expect(report_reader.proofing_rate_table).to eq(csv_data)
      expect(report_reader).to have_received(:csv_data_for).with('proofing_rate_metrics')
    end
  end
end
