require 'rails_helper'
require 'reporting/drop_off_report'

RSpec.describe Reporting::DropOffReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::DropOffReport.new(issuers: [issuer], time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        # finishes funnel
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: phone of record visited' },
        { 'user_id' => 'user1', 'name' => 'idv_enter_password_visited' },
        { 'user_id' => 'user1', 'name' => 'idv_enter_password_submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: personal key submitted' },

        # gets through phone finder, then drops
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth ssn visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify visited' },
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth verify submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: phone of record visited' },

        # gets to SSN view, then drops
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth document_capture visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth ssn visited' },

        # uploads a document, then drops
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth welcome submitted' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth document_capture visited' },

        # bails after viewing the user agreement
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome visited' },
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth welcome submitted' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#as_tables' do
    it 'generates the tabular csv data' do
      expect(report.as_tables).to eq expected_tables
    end
  end

  describe '#as_emailable_reports' do
    it 'adds a "first row" hash with a title for tables_report mailer' do
      reports = report.as_emailable_reports
      aggregate_failures do
        reports.each do |report|
          expect(report.title).to be_present
        end
      end
    end
  end

  describe '#to_csvs' do
    it 'generates a csv' do
      csv_string_list = report.to_csvs
      expect(csv_string_list.count).to be 3

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
    let(:subject) { described_class.new(issuers: Array(issuer), time_range:, **opts) }
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
      # these two tables are static
      report.step_definition_table,
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
      ],
      [
        ['Step', 'Unique user count', 'Users lost', 'Dropoff from last step',
         'Users left from start'],
        ['Welcome (page viewed)'] + string_or_num(strings, 5),
        ['User agreement (page viewed)'] + string_or_num(strings, 5, 0, 0.0, 1.0),
        ['Capture Document (page viewed)'] + string_or_num(strings, 4, 1, 0.2, 0.8),
        ['Document submitted (event)'] + string_or_num(strings, 4, 0, 0.0, 0.8),
        ['SSN (page view)'] + string_or_num(strings, 3, 1, 0.25, 0.6),
        ['Verify Info (page view)'] + string_or_num(strings, 2, 1, 0.3333333333333333, 0.4),
        ['Verify submit (event)'] + string_or_num(strings, 2, 0, 0.0, 0.4),
        ['Phone finder (page view)'] + string_or_num(strings, 2, 0, 0.0, 0.4),
        ['Encrypt account: enter password (page view)'] + string_or_num(strings, 1, 1, 0.5, 0.2),
        ['Personal key input (page view)'] + string_or_num(strings, 1, 0, 0.0, 0.2),
        ['Verified (event)'] + string_or_num(strings, 1, 0, 0.0, 0.2),
        ['Workflow Complete - Total Pending'] + string_or_num(strings, 0),
      ],
    ]
  end

  def string_or_num(strings, *values)
    strings ? values.map(&:to_s) : values
  end
end
