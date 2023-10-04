require 'rails_helper'
require 'reporting/authentication_report'

RSpec.describe Reporting::AuthenticationReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::AuthenticationReport.new(issuers: [issuer], time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
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

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#as_tables' do
    it 'generates the tabular csv data' do
      expect(report.as_tables).to eq expected_tables
    end
  end

  describe '#as_tables_with_names' do
    it 'adds a "first row" hash with a title for tables_report mailer' do
      tables = report.as_tables_with_options
      aggregate_failures do
        tables.each do |table|
          expect(table[0][:title]).to_not be nil
        end
      end
    end
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv_string_list = report.to_csv
      expect(csv_string_list.count).to be 2

      csvs = csv_string_list.map { |csv| CSV.parse(csv) }

      aggregate_failures do
        csvs.map(&:to_a).zip(expected_tables(strings: true)).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: [issuer], time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 5,
        ensure_complete_logs: true,
        slice_interval: 3.hours,
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

  def expected_tables(strings: false)
    [
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
        ['Total # of IAL1 Users', strings ? '2' : 2],
      ],
      [
        ['Metric', 'Number of accounts', '% of total from start'],
        ['New Users Started IAL1 Verification', strings ? '4' : 4, '100.0%'],
        ['New Users Completed IAL1 Password Setup', strings ? '3' : 3, '75.0%'],
        ['New Users Completed IAL1 MFA', strings ? '2' : 2, '50.0%'],
        ['New IAL1 Users Consented to Partner', strings ? '1' : 1, '25.0%'],
        ['AAL2 Authentication Requests from Partner', strings ? '5' : 5, '100.0%'],
        ['AAL2 Authenticated Requests', strings ? '2' : 2, '40.0%'],
      ],
    ]
  end
end
