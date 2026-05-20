# frozen_string_literal: true

require 'rails_helper'
require 'reporting/demographics_metrics_s3_report'

RSpec.describe Reports::DemographicsMetricsS3Report do
  let(:frozen_time) { Time.zone.parse('2026-05-04 10:00:00') } # Day after reporting-rails upload
  let(:run_date) { frozen_time }
  let(:days_back) { 5 }
  let(:receiver) { :internal }
  let(:time_frame) { 'quarterly' }

  let(:bucket_name) { 'test-data-warehouse-bucket-123456789-us-west-2' }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }

  let(:issuer1) { 'urn:gov:gsa:openidconnect.profiles:sp:sso:ssa:benefits' }
  let(:issuer2) { 'urn:gov:gsa:openidconnect.profiles:sp:sso:va:healthcare' }

  let(:mock_configs) do
    [
      {
        'issuer_string' => issuer1,
        'internal_emails' => ['gsa.internal@example.com'],
        'partner_emails' => ['ssa.partner@example.com'],
      },
      {
        'issuer_string' => issuer2,
        'internal_emails' => ['gsa.internal@example.com'],
        'partner_emails' => ['va.partner@example.com'],
      },
    ]
  end

  let(:sp_metadata) do
    {
      issuer1 => {
        id: 123,
        friendly_name: 'SSA Benefits Portal',
        active: true,
        agency_id: 1,
        agency_name: 'Social Security Administration',
        agency_abbreviation: 'SSA',
        issuer_string: issuer1,
      },
      issuer2 => {
        id: 456,
        friendly_name: 'VA Healthcare Portal',
        active: true,
        agency_id: 2,
        agency_name: 'Veterans Affairs',
        agency_abbreviation: 'VA',
        issuer_string: issuer2,
      },
    }
  end

  let(:csv_data) do
    {
      'definitions' => <<~CSV,
        Metric,Unit,Definition
        Age range/Verification Demographics,Count,The number of users for this issuer who verified within the reporting period
      CSV
      'overview' => <<~CSV,
        Report Timeframe,2026-01-01 to 2026-03-31
        Report Generated,2026-05-05
        Issuer,#{issuer1}
      CSV
      'age_metrics' => <<~CSV,
        Age Range,User Count
        20-29,15
        30-39,25
      CSV
      'state_metrics' => <<~CSV,
        State,User Count
        CA,20
        TX,10
        NY,10
      CSV
    }
  end

  around do |example|
    travel_to(frozen_time) { example.run }
  end

  before do
    allow(IdentityConfig.store).to receive(:demographics_metrics_s3_report_configs)
      .and_return(mock_configs)
    allow(IdentityConfig.store).to receive(:s3_data_warehouse_replica_bucket_prefix)
      .and_return('test-data-warehouse-bucket')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('123456789')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-2')
    allow(Identity::Hostdata).to receive(:env).and_return('prod')

    allow_any_instance_of(JobHelpers::S3Helper).to receive(:s3_client).and_return(s3_client)

    # Mock the service provider metadata SQL query
    mock_sql_results = sp_metadata.map do |issuer, data|
      {
        'issuer' => issuer,
        'id' => data[:id],
        'friendly_name' => data[:friendly_name],
        'active' => data[:active],
        'agency_id' => data[:agency_id],
        'agency_name' => data[:agency_name],
        'agency_abbreviation' => data[:agency_abbreviation],
      }
    end

    connection = double('connection')
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    allow(connection).to receive(:execute).and_return(mock_sql_results)

    # Mock BaseReport method
    allow_any_instance_of(described_class).to receive(:generate_base_s3_path)
      .with(directory: 'idp').and_return('env/idp/')

    # Default S3 stubbing - files exist and are fresh
    setup_s3_responses(fresh: [123, 456])
  end

  subject(:job) { described_class.new(run_date, days_back, receiver, time_frame) }

  describe '#initialize' do
    context 'with valid parameters' do
      it 'sets instance variables correctly' do
        expect(job.run_date).to eq(run_date)
        expect(job.days_back_for_time_period).to eq(days_back)
        expect(job.report_receiver).to eq(:internal)
        expect(job.time_frame).to eq('quarterly')
      end
    end

    context 'with defaults' do
      subject(:default_job) { described_class.new }

      it 'uses default values' do
        expect(default_job.run_date).to be_within(1.second).of(Time.zone.now)
        expect(default_job.days_back_for_time_period).to eq(5)
        expect(default_job.report_receiver).to eq(:internal)
        expect(default_job.time_frame).to eq('quarterly')
      end
    end

    context 'with invalid parameters' do
      it 'raises error for invalid days_back' do
        expect { described_class.new(run_date, 95, receiver, time_frame) }
          .to raise_error(ArgumentError, /days_back_for_time_period must be between 0 and 90/)
      end

      it 'raises error for invalid receiver' do
        expect { described_class.new(run_date, days_back, :external, time_frame) }
          .to raise_error(ArgumentError, /report_receiver must be :internal or :both/)
      end

      it 'raises error for invalid time_frame' do
        expect { described_class.new(run_date, days_back, receiver, 'weekly') }
          .to raise_error(ArgumentError, /time_frame must be quarterly, monthly, or daily/)
      end
    end
  end

  describe '#perform' do
    context 'with no configurations' do
      before do
        allow(IdentityConfig.store).to receive(:demographics_metrics_s3_report_configs)
          .and_return([])
      end

      it 'logs warning and returns false' do
        expect(Rails.logger).to receive(:warn)
          .with('No issuer configurations found - Demographics Metrics S3 Report NOT SENT')
        expect(job.perform).to eq(false)
      end
    end

    context 'with valid configurations' do
      it 'processes all issuers successfully' do
        expect(Rails.logger).to receive(:info)
          .with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:info)
          .with("Processing demographics report for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:info)
          .with("Successfully sent demographics report for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:info)
          .with("Processing demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info)
          .with("Successfully sent demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info)
          .with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).to receive(:tables_report).twice.and_return(
          double(deliver_now: true),
        )

        job.perform
      end

      it 'uses perform parameters over constructor parameters' do
        new_date = Time.zone.parse('2026-06-01')
        new_days = 3
        new_receiver = :both

        job.perform(new_date, new_days, new_receiver, 'monthly')

        expect(job.run_date).to eq(new_date)
        expect(job.days_back_for_time_period).to eq(new_days)
        expect(job.report_receiver).to eq(:both)
        expect(job.time_frame).to eq('monthly')
      end
    end

    context 'with missing service provider' do
      before do
        # Remove issuer1 from metadata
        allow_any_instance_of(described_class).to receive(:get_service_provider_info)
          .with(issuer1).and_return(nil)
        allow_any_instance_of(described_class).to receive(:get_service_provider_info)
          .with(issuer2).and_return(sp_metadata[issuer2])
      end

      it 'skips missing SP and continues processing' do
        # Remove the "Processing demographics report" expectation for issuer1
        # since it returns early when SP is not found
        expect(Rails.logger).to receive(:info).with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:error)
          .with("No service provider found for issuer: #{issuer1} - skipping")
        expect(Rails.logger).to receive(:info).with("Processing demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info)
          .with("Successfully sent demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info).with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).to receive(:tables_report).once.and_return(
          double(deliver_now: true),
        )

        job.perform
      end
    end

    context 'with missing S3 files' do
      before do
        # Override the default stubbing to make SP123 files missing
        setup_s3_responses(missing: [123], fresh: [456])
      end

      it 'logs detailed error information and skips issuer' do
        expect(Rails.logger).to receive(:info).ordered
          .with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:info).ordered
          .with("Processing demographics report for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:error).ordered
          .with("Missing report files for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:error).ordered
          .with('  Service Provider ID: 123')
        expect(Rails.logger).to receive(:error).ordered
          .with('  Agency: SSA')
        expect(Rails.logger).to receive(:error).ordered
          .with(/Missing files:.*definitions/)
        expect(Rails.logger).to receive(:error).ordered
          .with(/Expected path:.*SP123/)
        expect(Rails.logger).to receive(:error).ordered
          .with("  Bucket: #{bucket_name}")
        expect(Rails.logger).to receive(:error).ordered
          .with('  Time frame: quarterly (Q22026)')
        expect(Rails.logger).to receive(:error).ordered
          .with('  Report receiver: internal')

        expect(Rails.logger).to receive(:info).ordered.with("Processing demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info).ordered.with("Successfully sent demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info).ordered.with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).to receive(:tables_report).once.and_return(
          double(deliver_now: true),
        )

        job.perform
      end
    end

    context 'with old S3 files' do
      before do
        setup_s3_responses(old: [123], fresh: [456])
      end

      it 'logs error about old files and skips issuer' do
        expect(Rails.logger).to receive(:info).with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:info).with("Processing demographics report for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:error)
          .with("Report files are too old for issuer: #{issuer1} - skipping")
        expect(Rails.logger).to receive(:info).with("Processing demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info).with("Successfully sent demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:info).with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).to receive(:tables_report).once.and_return(
          double(deliver_now: true),
        )

        job.perform
      end
    end

    context 'with configuration validation errors' do
      let(:invalid_configs) do
        [
          { 'issuer_string' => '', 'internal_emails' => ['test@example.com'] },
          { 'issuer_string' => 'valid.issuer', 'internal_emails' => [], 'partner_emails' => [] },
        ]
      end

      before do
        allow(IdentityConfig.store).to receive(:demographics_metrics_s3_report_configs)
          .and_return(invalid_configs)
      end

      it 'skips invalid configs with appropriate logging' do
        expect(Rails.logger).to receive(:info).with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:error).with('Missing issuer_string for config')
        expect(Rails.logger).to receive(:error).with('No emails provided for issuer valid.issuer')
        expect(Rails.logger).to receive(:info).with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).not_to receive(:tables_report)

        job.perform
      end
    end

    context 'with email recipient handling' do
      it 'sends to internal emails only when receiver is :internal' do
        job = described_class.new(run_date, days_back, :internal, time_frame)

        # Both issuers should use internal emails when job receiver is :internal
        expect(ReportMailer).to receive(:tables_report).with(
          hash_including(
            to: ['gsa.internal@example.com'], # Both use internal emails
            bcc: [],
          ),
        ).and_return(double(deliver_now: true)).twice # Both issuers

        job.perform
      end

      it 'sends to partner emails with internal BCC when receiver is :both' do
        job = described_class.new(run_date, days_back, :both, time_frame)

        # First issuer (SSA)
        expect(ReportMailer).to receive(:tables_report).with(
          hash_including(
            to: ['ssa.partner@example.com'],
            bcc: ['gsa.internal@example.com'],
          ),
        ).and_return(double(deliver_now: true))

        # Second issuer (VA)
        expect(ReportMailer).to receive(:tables_report).with(
          hash_including(
            to: ['va.partner@example.com'],
            bcc: ['gsa.internal@example.com'],
          ),
        ).and_return(double(deliver_now: true))

        job.perform
      end

      it 'warns when receiver is :both but no partner emails' do
        # Remove partner emails from one config
        mock_configs[0]['partner_emails'] = [] # Remove SSA partner emails

        expect(Rails.logger).to receive(:warn)
          .with(/SSA Demographics Metrics Report: recipient is :both but no external email/)

        # Should still send to internal emails for SSA, and normally for VA
        expect(ReportMailer).to receive(:tables_report).twice.and_return(
          double(deliver_now: true),
        )

        job = described_class.new(run_date, days_back, :both, time_frame)
        job.perform
      end
    end

    context 'with non-production environment' do
      before do
        allow(Identity::Hostdata).to receive(:env).and_return('staging')
      end

      it 'includes non-production alert in email preamble' do
        expect(ReportMailer).to receive(:tables_report) do |args|
          expect(args[:message]).to include('Non-Production Report')
          expect(args[:message]).to include('staging')
          double(deliver_now: true)
        end.twice

        job.perform
      end
    end

    context 'with error handling' do
      it 'continues processing when one issuer fails' do
        # Force an error by making csv_data_for raise after files are validated to exist
        allow_any_instance_of(Reporting::DemographicsMetricsS3Report).to receive(:as_emailable_reports)
          .and_raise(StandardError, 'S3 read error')

        expect(Rails.logger).to receive(:info).with('Processing demographics reports for 2 issuers')
        expect(Rails.logger).to receive(:info).with("Processing demographics report for issuer: #{issuer1}")
        expect(Rails.logger).to receive(:error)
          .with("Failed to process demographics report for issuer #{issuer1}: S3 read error")
        expect(Rails.logger).to receive(:info).with("Processing demographics report for issuer: #{issuer2}")
        expect(Rails.logger).to receive(:error)
          .with("Failed to process demographics report for issuer #{issuer2}: S3 read error")
        expect(Rails.logger).to receive(:info).with('Completed demographics metrics S3 report processing')

        expect(ReportMailer).not_to receive(:tables_report)

        job.perform
      end
    end
  end

  describe 'private methods' do
    describe '#report_time_range_label' do
      it 'formats quarterly labels correctly' do
        # Q2 2026 (May 5 - 5 days = April 30, which is Q2)
        expect(job.send(:report_time_range_label)).to eq('Q22026')

        # Q4 2025
        q4_job = described_class.new(
          Time.zone.parse('2026-01-04'), 5, :internal, 'quarterly'
        )
        expect(q4_job.send(:report_time_range_label)).to eq('Q42025')
      end

      it 'formats monthly labels correctly' do
        monthly_job = described_class.new(
          Time.zone.parse('2026-05-04'), 5, :internal, 'monthly'
        )
        expect(monthly_job.send(:report_time_range_label)).to eq('Apr2026')
      end

      it 'formats daily labels correctly' do
        daily_job = described_class.new(
          Time.zone.parse('2026-05-04'), 1, :internal, 'daily'
        )
        expect(daily_job.send(:report_time_range_label)).to eq('May032026')
      end
    end

    describe '#report_time_range' do
      it 'calculates correct quarterly range' do
        range = job.send(:report_time_range)
        # May 5 - 5 days = April 30, which is Q2 2026
        expect(range.begin).to eq(Time.zone.parse('2026-04-01'))
        expect(range.end).to eq(Time.zone.parse('2026-06-30').end_of_day)
      end

      it 'calculates correct monthly range' do
        monthly_job = described_class.new(
          Time.zone.parse('2026-05-04'), 5, :internal, 'monthly'
        )
        range = monthly_job.send(:report_time_range)
        expect(range.begin).to eq(Time.zone.parse('2026-04-01'))
        expect(range.end).to eq(Time.zone.parse('2026-04-30').end_of_day)
      end
    end

    describe '#demographics_email_subject' do
      let(:report_reader) { instance_double(Reporting::DemographicsMetricsS3Report) }

      before do
        allow(report_reader).to receive(:csv_file_names).and_return(['definitions'])
        allow(report_reader).to receive(:get_file_last_modified)
          .and_return(Time.zone.parse('2026-05-04'))
      end

      it 'formats subject with agency abbreviation' do
        subject_line = job.send(:demographics_email_subject, 'SSA', report_reader)
        expect(subject_line).to eq(
          'SSA Verification Demographics Report Q22026 - 2026-05-04',
        )
      end

      it 'handles missing agency abbreviation' do
        expect(Rails.logger).to receive(:warn).with('Missing agency abbreviation')

        subject_line = job.send(:demographics_email_subject, nil, report_reader)
        expect(subject_line).to eq(
          'Verification Demographics Report Q22026 - 2026-05-04',
        )
      end

      it 'falls back to current date if S3 file access fails' do
        allow(report_reader).to receive(:get_file_last_modified)
          .and_raise(Aws::S3::Errors::NoSuchKey.new('', ''))

        expect(Rails.logger).to receive(:warn)
          .with('Unexpected S3 file access issue when getting modified date, using today for email subject')

        subject_line = job.send(:demographics_email_subject, 'VA', report_reader)
        expect(subject_line).to include(Date.current.strftime('%Y-%m-%d'))
      end
    end

    describe '#data_warehouse_bucket_name' do
      it 'constructs bucket name from config and hostdata' do
        expect(job.send(:data_warehouse_bucket_name)).to eq(bucket_name)
      end
    end
  end

  private

  def setup_s3_responses(config = {})
    # config structure:
    # {
    #   missing: [sp_id1, sp_id2],     # SPs with missing files
    #   old: [sp_id3],                 # SPs with old files
    #   fresh: [sp_id4, sp_id5]        # SPs with fresh files (default)
    # }

    stub_response = lambda do |context|
      key = context.params[:key]

      # Extract SP ID from key
      sp_match = key.match(/SP(\d+)/)
      return 'NoSuchKey' unless sp_match
      sp_id = sp_match[1].to_i

      # Check file type
      file_match = key.match(/_(definitions|overview|age_metrics|state_metrics)\.csv$/)
      return 'NoSuchKey' unless file_match
      report_type = file_match[1]

      # Determine response based on configuration
      if config[:missing]&.include?(sp_id)
        'NoSuchKey'
      elsif config[:old]&.include?(sp_id)
        if context.operation_name == :get_object
          { body: StringIO.new(csv_data[report_type] || '') }
        else # head_object
          { last_modified: 35.days.ago } # Old file
        end
      elsif context.operation_name == :get_object # Default to fresh files
        { body: StringIO.new(csv_data[report_type] || '') }
        else # head_object
          { last_modified: 1.day.ago } # Fresh file
      end
    end

    s3_client.stub_responses(:get_object, stub_response)
    s3_client.stub_responses(:head_object, stub_response)
  end
end
