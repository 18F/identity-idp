require 'rails_helper'
require 'reporting/irs_registration_funnel_report'

RSpec.describe Reporting::IrsRegistrationFunnelReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_week }
  let(:expected_definitions_table) do
    [
      ['Metric', 'Unit', 'Definition'],
      ['Registration Demand', 'Count',
       'The count of new users that started the registration process with Login.gov.'],
      ['Registration Failures', 'Count',
       'The count of new users who did not complete the registration process'],
      ['Registration Successes', 'Count',
       'The count of new users who completed the registration process sucessfully'],
      ['Registration Success Rate', 'Percentage',
       'The percentage of new users who completed registration process successfully'],
    ]
  end
  let(:expected_overview_table) do
    [
      ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
      ['Report Generated', Time.zone.today.to_s],
      ['Issuer', issuer],
    ]
  end
  let(:expected_funnel_metrics_table) do
    [
      ['Metric', 'Number of accounts', '% of total from start'],
      ['Registration Demand', 4, '100.0%'],
      ['Registration Failures', 2, '50.0%'],
      ['Registration Successes', 2, '50.0%'],
      ['Registration Success Rate', 1, '25.0%'],
    ]
  end

  subject(:report) { Reporting::IrsAuthenticationReport.new(issuers: [issuer], time_range:) }

  before do
    travel_to Time.zone.now.beginning_of_day
    stub_cloudwatch_logs(
      [
        # finishes funnel
        { 'user_id' => 'user1', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user1', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user1', 'name' => 'User Registration: 2FA Setup visited' },
        { 'user_id' => 'user1', 'name' => 'User Registration: User Fully Registered' },
        { 'user_id' => 'user1', 'name' => 'SP redirect initiated' },

        # first 3 steps
        { 'user_id' => 'user2', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user2', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user2', 'name' => 'User Registration: 2FA Setup visited' },
        { 'user_id' => 'user2', 'name' => 'User Registration: User Fully Registered' },

        # first 2 steps
        { 'user_id' => 'user3', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user3', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user3', 'name' => 'User Registration: 2FA Setup visited' },

        # first step only
        { 'user_id' => 'user4', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user4', 'name' => 'User Registration: Email Confirmation' },

        # already existing user, just signing in
        { 'user_id' => 'user5', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user5', 'name' => 'SP redirect initiated' },
      ],
    )
  end

  describe '#definitions_table' do
    it 'renders a definitions table' do
      aggregate_failures do
        report.definitions_table.zip(expected_definitions_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#overview_table' do
    it 'renders an overview table' do
      aggregate_failures do
        report.overview_table.zip(expected_overview_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#funnel_metrics_table' do
    it 'renders a funnel metrics table' do
      aggregate_failures do
        report.funnel_metrics_table.zip(expected_funnel_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#as_emailable_reports' do
    let(:expected_reports) do
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          filename: 'definitions',
          table: expected_definitions_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          filename: 'overview',
          table: expected_overview_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Registration Funnel Metrics',
          filename: 'funnel_metrics',
          table: expected_funnel_metrics_table,
        ),
      ]
    end
    it 'return expected table for email' do
      expect(report.as_emailable_reports).to eq expected_reports
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: [issuer], time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 1,
        ensure_complete_logs: true,
        slice_interval: 6.hours,
        progress: false,
        logger: nil,
      }
    end

    describe 'when all args are default' do
      it 'creates a client with the default options' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when verbose is passed in' do
      let(:opts) { { verbose: true } }
      let(:logger) { double Logger }

      before do
        expect(Logger).to receive(:new).with(STDERR).and_return logger
        default_args[:logger] = logger
      end

      it 'creates a client with the expected logger' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when progress is passed in as true' do
      let(:opts) { { progress: true } }
      before { default_args[:progress] = true }

      it 'creates a client with progress as true' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when threads is passed in' do
      let(:opts) { { threads: 17 } }
      before { default_args[:num_threads] = 17 }

      it 'creates a client with the expected thread count' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when slice is passed in' do
      let(:opts) { { slice: 2.weeks } }
      before { default_args[:slice_interval] = 2.weeks }

      it 'creates a client with expected time slice' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end
  end
end
