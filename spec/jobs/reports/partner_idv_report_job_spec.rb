require 'rails_helper'

RSpec.describe Reports::PartnerIdvReportJob do
  let(:report_date) { Date.new(2024, 1, 31).in_time_zone('UTC').end_of_day }
  let(:service_provider_id) { 42 }
  let(:month_start_calendar_id) { 202401 }

  let(:s3_data_warehouse_replica_bucket_prefix) { 'login-gov-dw-reports' }
  let(:aws_account_id) { '123456789012' }
  let(:aws_region) { 'us-west-2' }
  let(:expected_bucket) do
    "#{s3_data_warehouse_replica_bucket_prefix}-#{aws_account_id}-#{aws_region}"
  end

  let(:expected_s3_path) do
    'int/partner-idv-report/2024/2024-01-31.partner-idv-report.json'
  end

  let(:mock_results_json) { '[{"issuer":"urn:test:issuer","count_inauthentic_doc":5}]' }

  subject(:job) { described_class.new }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return(aws_account_id)
    allow(Identity::Hostdata).to receive(:aws_region).and_return(aws_region)
    allow(IdentityConfig.store).to receive(:s3_data_warehouse_replica_bucket_prefix)
      .and_return(s3_data_warehouse_replica_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    mock_report = instance_double(Reporting::PartnerIdvReport, results_json: mock_results_json)
    allow(Reporting::PartnerIdvReport).to receive(:new).with(
      service_provider_id: service_provider_id,
      month_start_calendar_id: month_start_calendar_id,
    ).and_return(mock_report)
  end

  describe '#perform' do
    it 'uploads JSON to the data warehouse S3 bucket at the correct path' do
      expect(job).to receive(:upload_file_to_s3_bucket).with(
        path: expected_s3_path,
        body: mock_results_json,
        content_type: 'application/json',
        bucket: expected_bucket,
      ).and_call_original

      job.perform(
        report_date,
        service_provider_id: service_provider_id,
        month_start_calendar_id: month_start_calendar_id,
      )
    end

    it 'uses the correct report date in the S3 path' do
      custom_date = Date.new(2024, 6, 15).in_time_zone('UTC').end_of_day
      expected_path = 'int/partner-idv-report/2024/2024-06-15.partner-idv-report.json'

      expect(job).to receive(:upload_file_to_s3_bucket).with(
        path: expected_path,
        body: mock_results_json,
        content_type: 'application/json',
        bucket: expected_bucket,
      ).and_call_original

      job.perform(
        custom_date,
        service_provider_id: service_provider_id,
        month_start_calendar_id: month_start_calendar_id,
      )
    end

    it 'instantiates PartnerIdvReport with the correct parameters' do
      expect(Reporting::PartnerIdvReport).to receive(:new).with(
        service_provider_id: service_provider_id,
        month_start_calendar_id: month_start_calendar_id,
      ).and_return(instance_double(Reporting::PartnerIdvReport, results_json: mock_results_json))
      allow(job).to receive(:upload_file_to_s3_bucket)

      job.perform(
        report_date,
        service_provider_id: service_provider_id,
        month_start_calendar_id: month_start_calendar_id,
      )
    end
  end
end
