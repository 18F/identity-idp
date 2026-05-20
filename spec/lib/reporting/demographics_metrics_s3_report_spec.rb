# frozen_string_literal: true

require 'rails_helper'
require 'reporting/demographics_metrics_s3_report'

RSpec.describe Reporting::DemographicsMetricsS3Report do
  let(:bucket_name) { 'test-bucket' }
  let(:custom_s3_path) { 'test/path/to/reports' }
  let(:agency_abbreviation) { 'GSA' }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_helper) { instance_double(JobHelpers::S3Helper) }

  let(:report_reader) do
    described_class.new(
      bucket_name: bucket_name,
      custom_s3_path: custom_s3_path,
      agency_abbreviation: agency_abbreviation,
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
      expect(report_reader.agency_abbreviation).to eq(agency_abbreviation)
    end

    it 'allows nil agency_abbreviation' do
      reader = described_class.new(
        bucket_name: bucket_name,
        custom_s3_path: custom_s3_path,
        agency_abbreviation: nil,
      )
      expect(reader.agency_abbreviation).to be_nil
    end
  end

  describe '#csv_file_names' do
    it 'returns the expected file names' do
      expect(report_reader.csv_file_names).to eq(
        %w[
          definitions
          overview
          age_metrics
          state_metrics
        ],
      )
    end
  end

  describe '#csv_data_for' do
    let(:csv_content) { "header1,header2\nvalue1,value2\nvalue3,value4" }
    let(:parsed_csv) { [['header1', 'header2'], ['value1', 'value2'], ['value3', 'value4']] }
    let(:s3_response) { instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new(csv_content)) }

    before do
      allow(s3_client).to receive(:get_object).and_return(s3_response)
    end

    it 'fetches and parses CSV data from S3' do
      result = report_reader.csv_data_for('definitions')

      expect(s3_client).to have_received(:get_object).with(
        bucket: bucket_name,
        key: "#{custom_s3_path}_definitions.csv",
      )
      expect(result).to eq(parsed_csv)
    end

    it 'memoizes the result' do
      # First call
      result1 = report_reader.csv_data_for('overview')
      # Second call - should not hit S3 again
      result2 = report_reader.csv_data_for('overview')

      expect(s3_client).to have_received(:get_object).once
      expect(result1).to eq(result2)
    end

    it 'fetches different reports independently' do
      report_reader.csv_data_for('definitions')
      report_reader.csv_data_for('overview')

      expect(s3_client).to have_received(:get_object).twice
    end

    context 'when S3 file does not exist' do
      before do
        allow(s3_client).to receive(:get_object).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, 'Key not found'),
        )
      end

      it 'logs an error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(/Unexpected failure reading CSV file from S3/)

        expect { report_reader.csv_data_for('definitions') }.to raise_error(Aws::S3::Errors::NoSuchKey)
      end
    end
  end

  describe '#get_file_last_modified' do
    let(:last_modified) { Time.zone.now - 1.day }
    let(:head_response) { instance_double(Aws::S3::Types::HeadObjectOutput, last_modified: last_modified) }

    before do
      allow(s3_client).to receive(:head_object).and_return(head_response)
    end

    it 'returns the last modified time for a file' do
      result = report_reader.get_file_last_modified('age_metrics')

      expect(s3_client).to have_received(:head_object).with(
        bucket: bucket_name,
        key: "#{custom_s3_path}_age_metrics.csv",
      )
      expect(result).to eq(last_modified)
    end

    context 'when file does not exist' do
      before do
        allow(s3_client).to receive(:head_object).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, 'Key not found'),
        )
      end

      it 'raises NoSuchKey error' do
        expect { report_reader.get_file_last_modified('missing_file') }.to raise_error(
          Aws::S3::Errors::NoSuchKey,
        )
      end
    end
  end

  describe '#as_emailable_reports' do
    let(:csv_data) { [['col1', 'col2'], ['data1', 'data2']] }

    before do
      allow(report_reader).to receive(:definitions_table).and_return(csv_data)
      allow(report_reader).to receive(:overview_table).and_return(csv_data)
      allow(report_reader).to receive(:age_metrics_table).and_return(csv_data)
      allow(report_reader).to receive(:state_metrics_table).and_return(csv_data)
    end

    it 'returns an array of EmailableReport objects' do
      reports = report_reader.as_emailable_reports

      expect(reports).to all(be_a(Reporting::EmailableReport))
      expect(reports.size).to eq(4)
    end

    it 'sets correct titles and filenames' do
      reports = report_reader.as_emailable_reports

      expect(reports[0].title).to eq('Definitions')
      expect(reports[0].filename).to eq('definitions')

      expect(reports[1].title).to eq('Overview')
      expect(reports[1].filename).to eq('overview')

      expect(reports[2].title).to eq('GSA Age Metrics')
      expect(reports[2].filename).to eq('age_metrics')

      expect(reports[3].title).to eq('GSA State Metrics')
      expect(reports[3].filename).to eq('state_metrics')
    end

    context 'when agency_abbreviation is nil' do
      let(:agency_abbreviation) { nil }

      it 'excludes agency prefix from metric titles' do
        reports = report_reader.as_emailable_reports

        expect(reports[2].title).to eq('Age Metrics')
        expect(reports[3].title).to eq('State Metrics')
      end
    end
  end

  describe 'individual table methods' do
    let(:csv_data) { [['header'], ['data']] }

    before do
      allow(report_reader).to receive(:csv_data_for).and_return(csv_data)
    end

    describe '#definitions_table' do
      it 'returns CSV data for definitions' do
        expect(report_reader.definitions_table).to eq(csv_data)
        expect(report_reader).to have_received(:csv_data_for).with('definitions')
      end
    end

    describe '#overview_table' do
      it 'returns CSV data for overview' do
        expect(report_reader.overview_table).to eq(csv_data)
        expect(report_reader).to have_received(:csv_data_for).with('overview')
      end
    end

    describe '#age_metrics_table' do
      it 'returns CSV data for age_metrics' do
        expect(report_reader.age_metrics_table).to eq(csv_data)
        expect(report_reader).to have_received(:csv_data_for).with('age_metrics')
      end
    end

    describe '#state_metrics_table' do
      it 'returns CSV data for state_metrics' do
        expect(report_reader.state_metrics_table).to eq(csv_data)
        expect(report_reader).to have_received(:csv_data_for).with('state_metrics')
      end
    end
  end
end
